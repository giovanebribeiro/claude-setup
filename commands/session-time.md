/session-time
Calcula o tempo despreendido na conversa atual com Claude Code. Sem argumentos. Auto-calibra os pesos R/W/T a cada execucao.

Modelo de tempo
tempo_usuario(turno) = min(gap_real, max(K * esperado, FLOOR))

esperado = chars_resposta / R  +  T  +  chars_mensagem / W

R = chars/min leitura   W = chars/min digitacao   T = segundos pensando
K = 3.0   FLOOR = 15min
Se o gap real for menor que o esperado, usa o real. O estimado so entra como teto para afastamentos.

Pesos lidos de ~/.claude/session-time.yaml se existir; senao usa defaults (R=1000, W=250, T=90). Recalibra e salva ao final se tiver pelo menos 5 turnos sem afastamento.

Passo 1 — Calcular, calibrar e exibir
Execute via Bash com Python:

import json, os, glob, sys
sys.stdout.reconfigure(encoding='utf-8')
from datetime import datetime, timezone

# -- pesos -----------------------------------------------------------------
WEIGHTS_FILE = os.path.join(os.path.expanduser('~'), '.claude', 'session-time.yaml')

def load_weights():
    if os.path.exists(WEIGHTS_FILE):
        try:
            import yaml
            with open(WEIGHTS_FILE, encoding='utf-8') as f:
                w = yaml.safe_load(f)
            return w.get('reading_speed', 1000), \
                   w.get('typing_speed',  250),  \
                   w.get('think_seconds', 90),   \
                   True
        except: pass
    return 1000, 250, 90, False

R, W, T, was_calibrated = load_weights()
K = 3.0; FLOOR = 15 * 60

# -- localiza projeto ------------------------------------------------------
cwd = os.getcwd()
drive, rest = os.path.splitdrive(cwd)
if drive:
    drive_letter = drive.rstrip(':')
    rest_clean = rest.lstrip(os.sep).replace(os.sep, '--')
    project_key = f'{drive_letter}--{rest_clean}'
else:
    # Linux/macOS: sem drive letter
    project_key = rest.lstrip('/').replace('/', '--')

projects_base = os.path.join(os.path.expanduser('~'), '.claude', 'projects')
project_dir   = os.path.join(projects_base, project_key)

if not os.path.isdir(project_dir):
    candidates = []
    if os.path.isdir(projects_base):
        needle = rest_clean.replace('-', '').lower()
        for d in os.listdir(projects_base):
            if needle in d.replace('-', '').lower():
                candidates.append(d)
    if len(candidates) == 1:
        project_key = candidates[0]
        project_dir = os.path.join(projects_base, project_key)
    else:
        print(f'Diretorio nao encontrado: {project_dir}')
        if candidates:
            for c in candidates: print('  ' + c)
        elif os.path.isdir(projects_base):
            for d in sorted(os.listdir(projects_base))[:10]: print('  ' + d)
        exit(1)

# -- coleta eventos --------------------------------------------------------
# coleta todos os eventos relevantes primeiro
raw = []
files = glob.glob(os.path.join(project_dir, '*.jsonl'))
for f in files:
    with open(f, encoding='utf-8') as fh:
        for line in fh:
            try:
                obj = json.loads(line)
                if obj.get('type') not in ('user', 'assistant'): continue
                if obj.get('isSidechain'): continue
                msg     = obj.get('message', {})
                content = msg.get('content', '')
                ts      = datetime.fromisoformat(obj['timestamp'].replace('Z', '+00:00'))
                if obj['type'] == 'user':
                    if not isinstance(content, str) or not content.strip(): continue
                    chars    = len(content)
                    is_skill = '# /session-time' in content[:120]
                else:
                    if not isinstance(content, list): continue
                    chars    = sum(len(b.get('text','')) for b in content if b.get('type')=='text')
                    if not chars: continue
                    is_skill = False
                raw.append({'role': obj['type'], 'ts': ts, 'chars': chars, 'skip': is_skill})
            except: pass

raw.sort(key=lambda e: e['ts'])

# marca o assistant imediatamente seguinte a cada invocacao de skill como skip
for i, ev in enumerate(raw):
    if ev['skip'] and ev['role'] == 'user':
        for j in range(i+1, len(raw)):
            if raw[j]['role'] == 'assistant':
                raw[j]['skip'] = True
                break
            if raw[j]['role'] == 'user':
                break  # outro user antes do assistant, nao marca

turns = [e for e in raw if not e['skip']]
if not turns:
    print('Nenhum evento encontrado.')
    exit(0)

def fmt(s):
    s = int(s)
    if s < 60:   return f'{s}s'
    if s < 3600: return f'{s//60}min {s%60:02d}s'
    return f'{s//3600}h {(s%3600)//60:02d}min'

def to_local(dt):
    if dt.tzinfo is None: dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone().replace(tzinfo=None)

# -- calcula pares ---------------------------------------------------------
pairs = []
for i, ev in enumerate(turns):
    if ev['role'] != 'user': continue
    for j in range(i+1, len(turns)):
        if turns[j]['role'] == 'assistant':
            claude_s   = (turns[j]['ts'] - ev['ts']).total_seconds()
            asst       = turns[j]
            for k in range(j+1, len(turns)):
                if turns[k]['role'] == 'user':
                    gap_s      = (turns[k]['ts'] - asst['ts']).total_seconds()
                    expected_s = (asst['chars']/R + turns[k]['chars']/W)*60 + T
                    cap_s      = max(K * expected_s, FLOOR)
                    counted_s  = min(gap_s, cap_s)
                    pairs.append({
                        'claude_s':   claude_s,
                        'gap_s':      gap_s,
                        'expected_s': expected_s,
                        'counted_s':  counted_s,
                        'asst_chars': asst['chars'],
                        'user_chars': turns[k]['chars'],
                        'capped':     gap_s > cap_s,
                    })
                    break
            break

if not pairs:
    print('Turnos insuficientes para calculo.')
    exit(0)

total_claude = sum(p['claude_s']  for p in pairs)
total_user   = sum(p['counted_s'] for p in pairs)
total_waste  = sum(max(0, p['gap_s'] - p['counted_s']) for p in pairs)
n_capped     = sum(1 for p in pairs if p['capped'])

# estatisticas por turno
user_times   = [p['counted_s'] for p in pairs]
claude_times = [p['claude_s']  for p in pairs]
min_turn     = min(user_times)
max_turn     = max(user_times)
avg_turn     = sum(user_times) / len(user_times)
avg_claude   = sum(claude_times) / len(claude_times)
avg_chars_asst = sum(p['asst_chars'] for p in pairs) / len(pairs)
avg_chars_user = sum(p['user_chars'] for p in pairs) / len(pairs)

# -- calibracao ------------------------------------------------------------
honest = [p for p in pairs if not p['capped'] and p['gap_s'] > 5]

# remove outliers de gap via IQR antes de calibrar
if len(honest) >= 4:
    gaps = sorted(p['gap_s'] for p in honest)
    q1 = gaps[len(gaps) // 4]
    q3 = gaps[3 * len(gaps) // 4]
    upper = q3 + 1.5 * (q3 - q1)
    honest = [p for p in honest if p['gap_s'] <= upper]

new_R, new_W, new_T = R, W, T
calib_note = 'defaults' if not was_calibrated else 'calibrado anteriormente'
calib_updated = False

if len(honest) >= 5:
    try:
        import numpy as np
        A = np.array([[p['asst_chars']/60, p['user_chars']/60, 1.0] for p in honest])
        b = np.array([p['gap_s'] for p in honest])
        coefs, _, _, _ = np.linalg.lstsq(A, b, rcond=None)
        c_r, c_w, c_t = coefs
        if c_r > 0 and c_w > 0 and c_t > 0:
            new_R = round(60 / c_r)
            new_W = round(60 / c_w)
            new_T = round(float(c_t))
            import yaml
            with open(WEIGHTS_FILE, 'w', encoding='utf-8') as f:
                yaml.dump({
                    'reading_speed': new_R, 'typing_speed': new_W,
                    'think_seconds': new_T,
                    'calibrated_at': datetime.now().strftime('%Y-%m-%d'),
                    'turns_used': len(honest),
                }, f, allow_unicode=True, default_flow_style=False)
            calib_updated = (new_R != R or new_W != W or new_T != T)
            calib_note = f'atualizado ({len(honest)} turnos)' if calib_updated else f'estavel ({len(honest)} turnos)'
    except ImportError:
        calib_note = 'numpy ausente'
else:
    calib_note = f'{calib_note} (poucos turnos: {len(honest)}<5)'

# -- exibe -----------------------------------------------------------------
primeiro = turns[0]['ts']
ultimo   = turns[-1]['ts']

print(f'\n  Projeto  : {project_key}')
print(f'  Periodo  : {to_local(primeiro).strftime("%d/%m/%Y %H:%M")} -> {to_local(ultimo).strftime("%d/%m/%Y %H:%M")}')
print()
print(f'  Tempo Claude (processamento) : {fmt(total_claude)}')
print(f'  Tempo voce   (leu+pens+digit): {fmt(total_user)}')
print(f'  Total despreendido           : {fmt(total_claude + total_user)}')
print(f'  Afastamentos descartados     : {fmt(total_waste)}')
print()
print(f'  Estatisticas por turno')
print(f'    Turnos totais  : {len(pairs)}  ({n_capped} afastamentos)')
print(f'    Menor turno    : {fmt(min_turn)}')
print(f'    Maior turno    : {fmt(max_turn)}  (sem afastamentos)')
print(f'    Media por turno: {fmt(avg_turn)}  voce  /  {fmt(avg_claude)}  Claude')
print(f'    Media chars    : {avg_chars_asst:.0f} chars/resposta Claude  |  {avg_chars_user:.0f} chars/msg voce')
print()
if calib_updated:
    print(f'  Pesos antes  R={R} leitura  |  W={W} digitacao  |  T={T}s pensar')
    print(f'  Pesos agora  R={new_R} leitura  |  W={new_W} digitacao  |  T={new_T}s pensar  [{calib_note}]')
else:
    print(f'  Pesos  R={R} chars/min leitura  |  W={W} chars/min digitacao  |  T={T}s pensar  [{calib_note}]')
Passo 2 — LOC e commits co-autorados
Execute sempre (independente de git). LOC conta o projeto inteiro; commits so aparecem se o diretorio for um repositorio git com commits co-autorados pelo Claude.

import subprocess, re, sys, os
sys.stdout.reconfigure(encoding='utf-8')

# -- LOC por linguagem -----------------------------------------------------
LANG_MAP = {
    '.java': 'Java', '.ts': 'TypeScript', '.tsx': 'TypeScript',
    '.js': 'JavaScript', '.py': 'Python', '.go': 'Go',
    '.kt': 'Kotlin', '.cs': 'C#', '.rb': 'Ruby', '.rs': 'Rust',
    '.cpp': 'C++', '.c': 'C', '.swift': 'Swift',
    '.html': 'HTML', '.css': 'CSS', '.scss': 'CSS',
}
IGNORE_DIRS = {
    'node_modules', '.git', 'dist', 'build', 'target',
    '__pycache__', '.venv', 'venv', '.gradle', '.mvn',
    'coverage', '.nyc_output', 'out', 'bin', 'obj',
}

loc_by_lang = {}
for dirpath, dirnames, filenames in os.walk(os.getcwd()):
    dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS]
    for fname in filenames:
        ext  = os.path.splitext(fname)[1].lower()
        lang = LANG_MAP.get(ext)
        if not lang: continue
        try:
            with open(os.path.join(dirpath, fname), encoding='utf-8', errors='ignore') as f:
                count = sum(1 for l in f if l.strip()
                            and not l.strip().startswith('//')
                            and not l.strip().startswith('#')
                            and not l.strip().startswith('*')
                            and not l.strip().startswith('/*'))
                loc_by_lang[lang] = loc_by_lang.get(lang, 0) + count
        except: pass

total_loc = sum(loc_by_lang.values())
if total_loc > 0:
    print(f'\n  LOC por linguagem\n')
    for lang, count in sorted(loc_by_lang.items(), key=lambda x: -x[1]):
        bar = '█' * min(22, count * 22 // total_loc)
        print(f'  {lang:<14} {count:>6,}  {bar}  {count*100//total_loc}%')
    print(f'  {"─"*46}')
    print(f'  {"TOTAL":<14} {total_loc:>6,} LOC')

# -- commits co-autorados (opcional — so se for repo git) ------------------
total_add = total_del = 0
hashes = []
try:
    result = subprocess.run(
        ['git', 'log', '--all', '--grep=Co-Authored-By: Claude', '--format=%H'],
        capture_output=True, text=True, timeout=10
    )
    hashes = [h.strip() for h in result.stdout.strip().splitlines() if h.strip()]
    for h in hashes:
        diff = subprocess.run(['git', 'diff', '--stat', f'{h}^..{h}'],
                              capture_output=True, text=True)
        for line in diff.stdout.splitlines():
            ins  = re.search(r'(\d+) insertion', line)
            dels = re.search(r'(\d+) deletion',  line)
            if ins:  total_add += int(ins.group(1))
            if dels: total_del += int(dels.group(1))
    if hashes:
        print(f'\n  Commits co-autorados pelo Claude\n')
        print(f'  {len(hashes)} commits  |  +{total_add:,} adicionadas  |  -{total_del:,} removidas  |  {total_add-total_del:+,} líquidas')
except Exception:
    pass  # nao e repo git, ou git nao disponivel

# -- comparativo -----------------------------------------------------------
loc_base = total_add if total_add > 0 else total_loc
loc_label = 'commits co-autorados' if total_add > 0 else 'pasta atual (sem commits co-autorados)'

if loc_base > 0:
    RATES = {
        'Otimista    (senior, stack conhecida) ': 15,
        'Realista    (time misto, code review) ':  8,
        'Conservador (stack nova, discovery)   ':  4,
    }
    print(f'\n  Comparativo AI vs. humano  (base: {loc_label})\n')
    for label, rate in RATES.items():
        horas = loc_base / rate
        print(f'  {label}  →  {horas:,.0f}h  ≈  {horas/8:,.0f} dias/pessoa')

    try:
        total_s = total_claude + total_user
        horas_realista = loc_base / 8
        proporcao = horas_realista / (total_s / 3600) if total_s > 0 else 0
        print(f'\n  Tempo despreendido (Claude+voce) : {fmt(total_s)}  (~{total_s/3600/8:.1f} dias)')
        print(f'  Proporcao (realista)             : ~{proporcao:.0f}x mais rapido')
    except: pass
Metodologia e referências
Modelo de tempo do usuário
O tempo de cada turno é estimado pelo modelo:

esperado = chars_resposta / R  +  T  +  chars_mensagem / W

tempo_usuario = min(gap_real, max(K × esperado, FLOOR))
R (chars/min): velocidade de leitura do usuário
W (chars/min): velocidade de digitação do usuário
T (segundos): tempo de reflexão entre leitura e resposta
K = 3.0: multiplicador de tolerância — evita cortar turnos legítimos de revisão
FLOOR = 15min: teto mínimo antes de classificar um gap como afastamento
O gap real é usado quando for menor que o teto estimado. O teto só entra para limitar pausas longas (almoço, reunião, etc.) que não representam trabalho ativo.

Calibração automática
A cada execução, os pesos R, W e T são recalibrados via mínimos quadrados (numpy.linalg.lstsq) sobre os turnos "honestos" — aqueles cujo gap real ficou abaixo do teto e acima de 5 segundos, sem outliers (filtro IQR: descarta gaps acima de Q3 + 1,5 × IQR antes da regressão).

Os pesos calibrados são salvos em ~/.claude/session-time.yaml e reutilizados nas próximas sessões, refinando-se continuamente ao comportamento real do usuário.

Estimativa de esforço humano (COCOMO II)
As taxas de produtividade usadas no comparativo AI vs. humano são baseadas em:

Boehm, B. et al. — Software Cost Estimation with COCOMO II (2000). Modelo empírico de referência da indústria para estimativa de esforço em projetos de software, derivado de centenas de projetos reais.
Jones, C. — Applied Software Measurement (3ª ed., 2008). Compilação de métricas de produtividade por perfil de time e tipo de projeto.
McConnell, S. — Software Estimation: Demystifying the Black Art (2006). Tradução prática das taxas COCOMO para contextos de time com diferentes níveis de senioridade e familiaridade com a stack.
As taxas adotadas (LOC/hora de desenvolvimento efetivo, incluindo testes, revisão e correções — não apenas digitação):

Perfil	LOC/hora
Otimista — sênior, stack conhecida	15
Realista — time misto, code review, bugs	8
Conservador — stack nova, discovery	4
O que é contado como LOC
Linhas não-vazias e não-comentários (//, #, *, /*) nos arquivos-fonte reconhecidos, excluindo diretórios de dependências e build (node_modules, dist, target, .venv, etc.).

Os commits co-autorados são identificados pela assinatura Co-Authored-By: Claude no histórico git e têm suas linhas somadas via git diff --stat, isolando apenas o trabalho produzido com assistência de IA.

Autor: Bruno Silva bruno.silva@trilliab3.com.br
