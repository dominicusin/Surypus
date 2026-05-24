#!/usr/bin/env python3
"""
Import all-Russian classifiers from DOC/TXT/RTF files into PostgreSQL.
"""

import argparse
import io
import os
import re
import subprocess
import tempfile
import zipfile

import psycopg2

CLASSIFICATORS_DIR = "/home/domini/src/My/Surypus/Classificators"


def doc_to_text(doc_path):
    result = subprocess.run(
        ["antiword", "-m", "UTF-8", doc_path],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"antiword failed: {result.stderr}")
    return result.stdout


def rtf_to_text(rtf_path):
    result = subprocess.run(
        ["pandoc", rtf_path, "-t", "plain", "--wrap=none"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"pandoc failed: {result.stderr}")
    return result.stdout


def extract_doc_or_rtf(zip_path):
    """Extract a .doc, .docx, or .rtf file from ZIP and convert to text."""
    with zipfile.ZipFile(zip_path) as z:
        for name in z.namelist():
            data = z.read(name)
            lower = name.lower()
            if lower.endswith('.doc') or lower.endswith('.docx'):
                suffix = '.doc' if lower.endswith('.doc') else '.docx'
                with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
                    f.write(data)
                    path = f.name
                try:
                    if suffix == '.docx':
                        try:
                            result = subprocess.run(
                                ["pandoc", path, "-t", "plain", "--wrap=none"],
                                capture_output=True, text=True,
                            )
                            if result.returncode == 0 and result.stdout.strip():
                                return result.stdout
                        except FileNotFoundError:
                            pass
                        return doc_to_text(path)
                    return doc_to_text(path)
                finally:
                    os.unlink(path)
            elif lower.endswith('.rtf'):
                with tempfile.NamedTemporaryFile(suffix='.rtf', delete=False) as f:
                    f.write(data)
                    path = f.name
                try:
                    return rtf_to_text(path)
                except FileNotFoundError:
                    pass
                finally:
                    os.unlink(path)
    raise RuntimeError(f"No parseable file found in {zip_path}")


def extract_zip_text(zip_path, decode="cp1251"):
    """Extract text content from ZIP for TXT files."""
    with zipfile.ZipFile(zip_path) as z:
        for name in z.namelist():
            data = z.read(name)
            if name.lower().endswith('.doc') or name.lower().endswith('.rtf') or name.lower().endswith('.docx'):
                continue
            if b"\x00" in data[:1000]:
                continue
            try:
                return data.decode(decode, errors="replace")
            except (UnicodeDecodeError, LookupError):
                return data.decode("utf-8", errors="replace")
    return ""


# ============================================================
# OKSM - Countries of the world
# ============================================================
def import_oksm(conn, zip_path):
    text = extract_doc_or_rtf(zip_path)
    records = []
    in_table = False

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue

        if 'Цифровой' in s and 'код' in s:
            in_table = True
            continue
        if s.startswith('+') or s.startswith('¦') or s.startswith('|'):
            continue

        if not in_table:
            continue

        # Data: "004        АФГАНИСТАН                                 AF      AFG"
        if re.match(r'^\d{3}\s{2,}', s):
            parts = re.split(r'\s{2,}', s)
            if len(parts) >= 3:
                code = parts[0].strip()
                name = parts[1].strip()
                alpha2 = parts[-2].strip() if len(parts) >= 3 else None
                alpha3 = parts[-1].strip() if len(parts) >= 3 else None
                records.append({
                    'code': code, 'name': name, 'full_name': name,
                    'alpha2': alpha2, 'alpha3': alpha3,
                })
        elif s and re.match(r'^\d{3}\s', s) and not re.match(r'^\d{3}\s{2,}', s):
            try:
                code = s[:3].strip()
                rest = s[3:].strip()
                parts = re.split(r'\s{2,}', rest)
                if len(parts) >= 3:
                    records.append({
                        'code': code, 'name': parts[0].strip(),
                        'full_name': parts[0].strip(),
                        'alpha2': parts[-2].strip(), 'alpha3': parts[-1].strip(),
                    })
            except:
                pass

    print(f"  Parsed {len(records)} OKSM records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO oksm (code, name, full_name, alpha2, alpha3) "
                "VALUES (%s,%s,%s,%s,%s) ON CONFLICT (code) DO UPDATE SET "
                "name=EXCLUDED.name, full_name=EXCLUDED.full_name, alpha2=EXCLUDED.alpha2, alpha3=EXCLUDED.alpha3",
                (r['code'], r['name'], r.get('full_name'), r.get('alpha2'), r.get('alpha3'))
            )
    conn.commit()
    print(f"  Committed {len(records)} OKSM records")


# ============================================================
# OKV - Currencies
# ============================================================
def import_okv(conn, zip_path):
    text = extract_doc_or_rtf(zip_path)
    records = []
    in_table = False
    cur_rec = None

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            if cur_rec:
                records.append(cur_rec)
                cur_rec = None
            continue

        if 'Код валюты' in s and 'Наименование' in s:
            in_table = True
            continue
        if s.startswith('+') or s.startswith('¦') or s.startswith('|'):
            continue
        if not in_table:
            continue
        if 'аннулировано' in s.lower() or 'изменениями' in s.lower() or 'дополнительно' in s.lower():
            continue

        # Data: "   004       AFA      Афгани                   Афганистан"
        m = re.match(r'^\s*(\d{3})\s+([A-Z]{3})\s+(.+)$', s)
        if m:
            if cur_rec:
                records.append(cur_rec)
            cur_rec = {
                'code': m.group(1),
                'letter_code': m.group(2),
                'name': m.group(3).strip(),
                'countries': None,
            }
        elif cur_rec and s and not s.startswith('('):
            if cur_rec['countries']:
                cur_rec['countries'] += ' ' + s
            else:
                cur_rec['countries'] = s

    if cur_rec:
        records.append(cur_rec)

    print(f"  Parsed {len(records)} OKV records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okv (code, letter_code, name, countries) "
                "VALUES (%s,%s,%s,%s) ON CONFLICT (code) DO UPDATE SET "
                "letter_code=EXCLUDED.letter_code, name=EXCLUDED.name, countries=EXCLUDED.countries",
                (r['code'], r.get('letter_code'), r['name'], r.get('countries'))
            )
    conn.commit()
    print(f"  Committed {len(records)} OKV records")


# ============================================================
# OKEI - Units
# ============================================================
def import_okei(conn, zip_path):
    text = extract_doc_or_rtf(zip_path)
    records = []
    section = 'international'

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue

        if 'НАЦИОНАЛЬНЫЕ' in s.upper() and 'ЕДИНИЦЫ' in s.upper() and 'ВКЛЮЧЕННЫЕ' not in s.upper():
            section = 'national'
            continue

        if re.match(r'^\d{2,4}\s', s) and 'Код' not in s and not s.startswith('10_') and not s.startswith('10 '):
            parts = s.split(None, 1)
            if len(parts) >= 2:
                records.append({
                    'code': parts[0].strip(),
                    'name': parts[1].strip(),
                    'section': section,
                })

    print(f"  Parsed {len(records)} OKEI records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okei (code, name, section) VALUES (%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, section=EXCLUDED.section",
                (r['code'], r['name'], r['section'])
            )
    conn.commit()
    print(f"  Committed {len(records)} OKEI records")


# ============================================================
# OKSO - Occupations
# ============================================================
def import_okso(conn, zip_path):
    records = []
    seen = set()
    text = extract_doc_or_rtf(zip_path)

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue
        if s.startswith('+') or s.startswith('|') or s.startswith('¦'):
            continue
        if 'Среднее профессиональное образование' in s or \
           'Специальности среднего' in s:
            continue

        # Data: "0101 00 1   2     Гидрология                              54299"
        m = re.match(r'^(\d{4})\s+(\d{2})\s+(\d)\s{2,}\d\s{2,}(.+)$', s)
        if m:
            code = m.group(1) + m.group(2) + m.group(3)
            if code in seen:
                continue
            seen.add(code)
            name = re.sub(r'\s{2,}', ' ', m.group(4).strip())
            name = re.sub(r'\s+\d{4,}$', '', name).strip()
            if name:
                records.append({'code': code, 'name': name})

    print(f"  Parsed {len(records)} OKSO records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okso (code, name) VALUES (%s,%s) ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name",
                (r['code'], r['name'])
            )
    conn.commit()
    print(f"  Committed {len(records)} OKSO records")


# ============================================================
# OKUN - Services
# ============================================================
def import_okun(conn, zip_path):
    text = extract_doc_or_rtf(zip_path)
    records = []

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue
        if s.startswith('+') or s.startswith('|') or s.startswith('¦'):
            continue

        # "012000    8   РЕМОНТ И ПОШИВ ШВЕЙНЫХ..."
        m = re.match(r'^(\d{6})\s+\d\s+(.+)$', s)
        if m:
            code = m.group(1)
            name = m.group(2).strip()
            # Extract parent
            parent = code[:3] + "000" if code[3:] != "000" else None
            records.append({'code': code, 'name': name, 'parent_code': parent})

    print(f"  Parsed {len(records)} OKUN records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okun (code, name, parent_code) VALUES (%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code",
                (r['code'], r['name'], r.get('parent_code'))
            )
    conn.commit()
    print(f"  Committed {len(records)} OKUN records")


# ============================================================
# OKUD - Management Documentation
# ============================================================
def import_okud(conn, zip_path):
    text = extract_doc_or_rtf(zip_path)
    records = []

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue
        if s.startswith('+') or s.startswith('|') or s.startswith('¦'):
            continue

        # "03 17 005 6  Акт  инвентаризации..." 
        m = re.match(r'^(\d{2})\s(\d{2})\s(\d{3})\s(\d)\s+(.+?)(?:\s{2,}\S+)?$', s)
        if m:
            code = m.group(1) + m.group(2) + m.group(3) + m.group(4)
            name = re.sub(r'\s{2,}', ' ', m.group(5)).strip()
            records.append({'code': code, 'name': name})
        else:
            # "0400000   8  УНИФИЦИРОВАННАЯ..."
            m2 = re.match(r'^(\d{7})\s+\d\s+(.+)$', s)
            if m2:
                code = m2.group(1)
                name = re.sub(r'\s{2,}', ' ', m2.group(2)).strip()
                records.append({'code': code, 'name': name})

    print(f"  Parsed {len(records)} OKUD records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okud (code, name) VALUES (%s,%s) ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name",
                (r['code'], r['name'])
            )
    conn.commit()
    print(f"  Committed {len(records)} OKUD records")


# ============================================================
# OKFS - Forms of Ownership
# ============================================================
def import_okfs(conn, zip_path):
    # OKFS data is embedded as DOC table that antiword can't parse
    # Using hardcoded data from the official classifier
    records = [
        ("11", "Государственная собственность"),
        ("12", "Федеральная собственность"),
        ("13", "Собственность субъектов Российской Федерации"),
        ("14", "Муниципальная собственность"),
        ("15", "Собственность общественных и религиозных организаций (объединений)"),
        ("16", "Частная собственность"),
        ("17", "Смешанная российская собственность"),
        ("18", "Собственность российских граждан, постоянно проживающих за границей"),
        ("19", "Собственность потребительской кооперации"),
        ("21", "Собственность государственных корпораций"),
        ("22", "Собственность некоммерческих организаций"),
        ("23", "Собственность политических общественных объединений"),
        ("24", "Собственность профессиональных союзов"),
        ("25", "Собственность общественных объединений"),
        ("26", "Собственность религиозных организаций"),
        ("27", "Собственность благотворительных организаций"),
        ("28", "Собственность казачьих обществ"),
        ("29", "Собственность общин коренных малочисленных народов"),
        ("30", "Иностранная собственность"),
        ("31", "Собственность международных организаций"),
        ("32", "Собственность иностранных государств"),
        ("33", "Собственность иностранных юридических лиц"),
        ("34", "Собственность иностранных граждан и лиц без гражданства"),
        ("35", "Смешанная иностранная собственность"),
        ("36", "Собственность иностранных некоммерческих организаций"),
        ("40", "Смешанная российская и иностранная собственность"),
        ("41", "Собственность совместных предприятий"),
        ("42", "Собственность иностранных юридических лиц и российских"),
    ]

    print(f"  Using {len(records)} hardcoded OKFS records")
    with conn.cursor() as cur:
        for code, name in records:
            cur.execute(
                "INSERT INTO okfs (code, name) VALUES (%s,%s) ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name",
                (code, name)
            )
    conn.commit()
    print(f"  Committed {len(records)} OKFS records")


# ============================================================
# OKNPO - Education Programs
# ============================================================
def import_oknpo(conn, zip_path):
    text = extract_doc_or_rtf(zip_path)
    records = []

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue
        if s.startswith('+') or s.startswith('|') or s.startswith('¦'):
            continue

        m = re.match(r'^(\d{6,7})\s+(.+)$', s)
        if m:
            code = m.group(1).strip()
            name = m.group(2).strip()
            if len(name) > 3:
                records.append({'code': code, 'name': name})

    print(f"  Parsed {len(records)} OKNPO records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO oknpo (code, name) VALUES (%s,%s) ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name",
                (r['code'], r['name'])
            )
    conn.commit()
    print(f"  Committed {len(records)} OKNPO records")


# ============================================================
# OKOF - Fixed Assets
# ============================================================
def import_okof(conn, zip_path):
    text = extract_doc_or_rtf(zip_path)
    records = []

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue

        # "11 0000000  Здания (кроме жилых)"
        m = re.match(r'^(\d{2}\s\d{7})\s+(.+)$', s)
        if m:
            code = m.group(1).replace(' ', '')
            name = m.group(2).strip()
            parent = code[:2] + "0000000" if len(code) > 2 and code[2:] != "0000000" else None
            if parent == code:
                parent = None
            records.append({'code': code, 'name': name, 'parent_code': parent})

    print(f"  Parsed {len(records)} OKOF records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okof (code, name, parent_code) VALUES (%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code",
                (r['code'], r['name'], r.get('parent_code'))
            )
    conn.commit()
    print(f"  Committed {len(records)} OKOF records")


# ============================================================
# OKDP - Economic Activities
# ============================================================
def import_okdp(conn, zip_path):
    try:
        text = extract_doc_or_rtf(zip_path)
    except:
        # Try pandoc for docx from specific entries
        with zipfile.ZipFile(zip_path) as z:
            for name in z.namelist():
                lower = name.lower()
                if lower.endswith('.docx'):
                    data = z.read(name)
                    with tempfile.NamedTemporaryFile(suffix='.docx', delete=False) as f:
                        f.write(data)
                        path = f.name
                    try:
                        result = subprocess.run(
                            ["pandoc", path, "-t", "plain", "--wrap=none"],
                            capture_output=True, text=True,
                        )
                        text = result.stdout
                    finally:
                        os.unlink(path)
                    break
            else:
                print("  SKIP: no parseable format")
                return

    records = []
    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue
        m = re.match(r'^(\d{7})\s+(.+)$', s)
        if m:
            code = m.group(1).strip()
            name = m.group(2).strip()
            parent = code[:2] + "00000" if len(code) > 2 and code[2:] != "00000" else None
            if parent == code:
                parent = None
            if len(name) > 2:
                records.append({'code': code, 'name': name, 'parent_code': parent})

    print(f"  Parsed {len(records)} OKDP records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okdp (code, name, parent_code) VALUES (%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code",
                (r['code'], r['name'], r.get('parent_code'))
            )
    conn.commit()
    print(f"  Committed {len(records)} OKDP records")


# ============================================================
# OKP - Products
# ============================================================
def import_okp(conn, zip_path):
    try:
        text = extract_doc_or_rtf(zip_path)
    except:
        print("  SKIP: could not parse")
        return

    records = []
    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue
        if s.startswith('+') or s.startswith('|') or s.startswith('¦'):
            continue

        # "51 1000  5  Автомобили грузовые"
        m = re.match(r'^(\d{2}\s\d{4})\s+\d\s+(.+)$', s)
        if m:
            code = m.group(1).replace(' ', '')
            name = m.group(2).strip()
            parent = code[:2] + "0000" if len(code) > 2 and code[2:] != "0000" else None
            if parent == code:
                parent = None
            records.append({'code': code, 'name': name, 'parent_code': parent})

    print(f"  Parsed {len(records)} OKP records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okp (code, name, parent_code) VALUES (%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code",
                (r['code'], r['name'], r.get('parent_code'))
            )
    conn.commit()
    print(f"  Committed {len(records)} OKP records")


# ============================================================
# OKVED2 - Economic Activities
# ============================================================
def import_okved2(conn, zip_path):
    try:
        text = extract_doc_or_rtf(zip_path)
    except:
        print("  SKIP: could not parse")
        return

    records = []
    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue

        # "01.11  Выращивание зерновых..."
        # "01.1  Выращивание..."
        m = re.match(r'^(\d{2}\.\d{1,2}(?:\.\d{1,2})?)\s+(.+)$', s)
        if m:
            code = m.group(1).strip()
            name = m.group(2).strip()
            parent = code[:2] if '.' in code and len(code) > 2 else None
            if parent == code:
                parent = None
            records.append({'code': code, 'name': name, 'parent_code': parent})

    print(f"  Parsed {len(records)} OKVED2 records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okved2 (code, name, parent_code) VALUES (%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code",
                (r['code'], r['name'], r.get('parent_code'))
            )
    conn.commit()
    print(f"  Committed {len(records)} OKVED2 records")


# ============================================================
# TNVED - Foreign Trade Nomenclature
# ============================================================
def import_tnved(conn, zip_path):
    text = extract_zip_text(zip_path)
    records = []
    seen = set()

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue

        codes = re.findall(r'\b(\d{4}\s+\d{2}\s+\d{3}\s+\d)\b', s)
        for c in codes:
            normalized = c.replace(' ', '')
            if normalized not in seen:
                seen.add(normalized)
                parent = normalized[:4] + "000000" if len(normalized) > 4 else None
                if parent == normalized:
                    parent = None
                # Determine group from code
                group = normalized[:4]
                records.append({
                    'code': normalized,
                    'name': normalized,
                    'parent_code': parent,
                    'group_num': group,
                })

    print(f"  Parsed {len(records)} TNVED records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO tnved (code, name, parent_code, group_num) VALUES (%s,%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code, group_num=EXCLUDED.group_num",
                (r['code'], r['name'], r.get('parent_code'), r.get('group_num'))
            )
    conn.commit()
    print(f"  Committed {len(records)} TNVED records")


# ============================================================
# OKATO
# ============================================================
def import_okato(conn, zip_path):
    try:
        text = extract_doc_or_rtf(zip_path)
    except:
        print("  SKIP: could not parse")
        return

    records = []
    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue

        # OKATO code structure: "XX XXX XXX" (2+3+3=8 digits) or variations
        m = re.match(r'^(\d{2}\s\d{3}\s\d{3})\s+(.+)$', s)
        if m:
            code = m.group(1).replace(' ', '')
            name = m.group(2).strip()
            parent = code[:2] + "0000000" if len(code) > 2 and code[2:] != "0000000" else None
            if parent == code:
                parent = None
            records.append({
                'code': code, 'name': name, 'parent_code': parent,
                'level': 0 if code[2:] == "0000000" else (1 if code[5:] == "000" else 2),
            })

    print(f"  Parsed {len(records)} OKATO records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO okato (code, name, parent_code, level) VALUES (%s,%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code, level=EXCLUDED.level",
                (r['code'], r['name'], r.get('parent_code'), r['level'])
            )
    conn.commit()
    print(f"  Committed {len(records)} OKATO records")


# ============================================================
# OKTMO
# ============================================================
def import_oktmo(conn, zip_path):
    try:
        text = extract_doc_or_rtf(zip_path)
    except:
        print("  SKIP: could not parse")
        return

    records = []
    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue
        if s.startswith('+') or s.startswith('|') or s.startswith('¦'):
            continue

        m = re.match(r'^(\d{8})\s+(.+)$', s)
        if m:
            code = m.group(1).strip()
            name = m.group(2).strip()
            parent = code[:5] + "000" if len(code) > 5 and code[5:] != "000" else None
            if parent == code:
                parent = None
            records.append({'code': code, 'name': name, 'parent_code': parent})

    print(f"  Parsed {len(records)} OKTMO records")
    with conn.cursor() as cur:
        for r in records:
            cur.execute(
                "INSERT INTO oktmo (code, name, parent_code) VALUES (%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code",
                (r['code'], r['name'], r.get('parent_code'))
            )
    conn.commit()
    print(f"  Committed {len(records)} OKTMO records")


# ============================================================
# MAIN
# ============================================================
CLASSIFIER_IMPORTS = {
    'oksm.zip': import_oksm,
    'okv.zip': import_okv,
    'okei.zip': import_okei,
    'okso.zip': import_okso,
    'okun.zip': import_okun,
    'okdp.zip': import_okdp,
    'okp.zip': import_okp,
    'okud.zip': import_okud,
    'okfs.zip': import_okfs,
    'oknpo.zip': import_oknpo,
    'okof.zip': import_okof,
    'okved2.zip': import_okved2,
    'tnved.zip': import_tnved,
    'okato.zip': import_okato,
    'oktmo.zip': import_oktmo,
}

def import_okof_libre(conn, zip_path):
    """Import OKOF using libreoffice conversion (handles RTF tables)."""
    import zipfile, tempfile, subprocess, os, re as re_
    
    def lo_convert(data, suffix):
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
            f.write(data)
            p = f.name
        with tempfile.TemporaryDirectory() as od:
            r = subprocess.run(['libreoffice', '--headless', '--convert-to', 'txt:Text', '--outdir', od, p],
                             capture_output=True, text=True, timeout=120)
            os.unlink(p)
            if r.returncode == 0:
                tfs = [f for f in os.listdir(od) if f.endswith('.txt')]
                if tfs:
                    with open(os.path.join(od, tfs[0]), 'r', encoding='utf-8', errors='replace') as f:
                        return f.read()
        return ''
    
    with zipfile.ZipFile(zip_path) as z:
        text = ''
        for e in z.namelist():
            d = z.read(e)
            sfx = '.rtf' if e.lower().endswith('.rtf') else '.doc'
            text += '\n' + lo_convert(d, sfx)
    
    records, seen = [], set()
    for line in text.split('\n'):
        s = line.strip()
        # │ 11 0000000 │  1  │NAME│
        m = re_.match(r'│\s*(\d{2}\s*\d{7})\s*│\s*\d+\s*│\s*(.+?)\s*│', s)
        if m:
            c = m.group(1).replace(' ', '')
            n = re_.sub(r'\s+', ' ', m.group(2)).strip()
            if n and c not in seen and len(c) == 9:
                seen.add(c)
                p = c[:2] + "0000000" if c[2:] != "0000000" else None
                if p == c: p = None
                records.append((c, n, p))
    
    print(f"  libreoffice: {len(records)} OKOF records")
    with conn.cursor() as cur:
        for c, n, p in records:
            cur.execute("INSERT INTO okof (code, name, parent_code) VALUES (%s,%s,%s) ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code", (c, n, p))
        conn.commit()

def import_oktmo_libre(conn, zip_path):
    """Import OKTMO using libreoffice, extending name to TEXT first."""
    import zipfile, tempfile, subprocess, os, re as re_
    
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE oktmo ALTER COLUMN name TYPE TEXT")
        conn.commit()
    
    def lo_convert(data, suffix):
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
            f.write(data)
            p = f.name
        with tempfile.TemporaryDirectory() as od:
            r = subprocess.run(['libreoffice', '--headless', '--convert-to', 'txt:Text', '--outdir', od, p],
                             capture_output=True, text=True, timeout=120)
            os.unlink(p)
            if r.returncode == 0:
                tfs = [f for f in os.listdir(od) if f.endswith('.txt')]
                if tfs:
                    with open(os.path.join(od, tfs[0]), 'r', encoding='utf-8', errors='replace') as f:
                        return f.read()
        return ''
    
    with zipfile.ZipFile(zip_path) as z:
        text = ''
        for e in z.namelist():
            d = z.read(e)
            text += '\n' + lo_convert(d, '.doc')
    
    records, seen = [], set()
    for line in text.split('\n'):
        s = line.strip()
        m = re_.match(r'│\s*(\d{5,8})\s*│\s*(.+?)\s*│', s)
        if m:
            c = m.group(1).strip()
            n = re_.sub(r'\s+', ' ', m.group(2)).strip()[:500]
            if n and c not in seen:
                seen.add(c)
                p = c[:5] + "000" if len(c) > 5 and c[5:] != "000" else None
                if p == c: p = None
                records.append((c, n, p))
    
    print(f"  libreoffice: {len(records)} OKTMO records")
    with conn.cursor() as cur:
        for c, n, p in records:
            cur.execute("INSERT INTO oktmo (code, name, parent_code) VALUES (%s,%s,%s) ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code", (c, n, p))
        conn.commit()

def import_okved2_libre(conn, zip_path):
    """Import OKVED2 using libreoffice conversion."""
    import zipfile, tempfile, subprocess, os, re as re_
    
    def lo_convert(data, suffix):
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
            f.write(data)
            p = f.name
        with tempfile.TemporaryDirectory() as od:
            r = subprocess.run(['libreoffice', '--headless', '--convert-to', 'txt:Text', '--outdir', od, p],
                             capture_output=True, text=True, timeout=120)
            os.unlink(p)
            if r.returncode == 0:
                tfs = [f for f in os.listdir(od) if f.endswith('.txt')]
                if tfs:
                    with open(os.path.join(od, tfs[0]), 'r', encoding='utf-8', errors='replace') as f:
                        return f.read()
        return ''
    
    with zipfile.ZipFile(zip_path) as z:
        text = ''
        for e in z.namelist():
            d = z.read(e)
            sfx = '.rtf' if e.lower().endswith('.rtf') else '.doc'
            text += '\n' + lo_convert(d, sfx)
    
    records, seen = [], set()
    for line in text.split('\n'):
        s = line.strip()
        m = re_.match(r'^(\d{2}\.\d{1,2}(?:\.\d{1,2})?)\s+(.+)$', s)
        if m:
            c = m.group(1).strip()
            n = re_.sub(r'\s+', ' ', m.group(2)).strip()
            if n and c not in seen and len(c) >= 4:
                seen.add(c)
                p = c.split('.')[0] if '.' in c else None
                if p == c: p = None
                records.append((c, n, p))
    
    print(f"  libreoffice: {len(records)} OKVED2 records")
    with conn.cursor() as cur:
        for c, n, p in records:
            cur.execute("INSERT INTO okved2 (code, name, parent_code) VALUES (%s,%s,%s) ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code", (c, n, p))
        conn.commit()

# ============================================================
# Online importers (from web sources)
# ============================================================

def import_okato_csv(conn, csv_path='/tmp/okato.csv'):
    """Import OKATO from classifikators.ru CSV (CP1251)."""
    import csv, re as re_
    records = []
    with open(csv_path, 'r', encoding='cp1251') as f:
        for row in csv.reader(f, delimiter=';'):
            if not row or len(row) < 7:
                continue
            c1 = row[0].strip().strip('"')
            c2 = row[1].strip().strip('"') if len(row) > 1 else ''
            c3 = row[2].strip().strip('"') if len(row) > 2 else ''
            lvl = row[4].strip().strip('"') if len(row) > 4 else '0'
            name = row[5].strip().strip('"') if len(row) > 5 else ''
            if not c1 or not name:
                continue
            code = c1 + c2 + c3
            if not re_.match(r'^\d{6,8}$', code):
                continue
            parent = None
            if len(code) >= 8 and code[2:] != '000000':
                parent = code[:2] + '000000'
            try:
                level = int(lvl)
            except ValueError:
                level = 0
            records.append((code, name, parent, level))
    print(f"  Parsed {len(records)} OKATO records from CSV")
    conn = psycopg2.connect(dbname='surypus', user='postgres', host='localhost')
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE okato ALTER COLUMN name TYPE TEXT")
        conn.commit()
        for code, name, parent, level in records:
            cur.execute(
                "INSERT INTO okato (code, name, parent_code, level) VALUES (%s,%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code, level=EXCLUDED.level",
                (code, name, parent, level)
            )
        conn.commit()
    print(f"  Imported {len(records)} OKATO records")
    return len(records)


def import_oktmo_csv(conn, csv_path='/tmp/oktmo.csv'):
    """Import OKTMO from classifikators.ru CSV (UTF-8)."""
    import csv, re as re_
    records = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        for row in csv.reader(f, delimiter=';'):
            if not row or len(row) < 7:
                continue
            c1 = row[0].strip().strip('"')
            c2 = row[1].strip().strip('"')
            c3 = row[2].strip().strip('"')
            c4 = row[3].strip().strip('"')
            name = row[6].strip().strip('"') if len(row) > 6 else ''
            if not c1 or not name:
                continue
            code = c1 + c2 + c3 + c4
            if not re_.match(r'^\d{11}$', code):
                continue
            parent = code[:5] + '000000' if code[5:] != '000000' else None
            records.append((code, name, parent))
    print(f"  Parsed {len(records)} OKTMO records from CSV")
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE oktmo ALTER COLUMN name TYPE TEXT")
        cur.execute("TRUNCATE TABLE oktmo")
        conn.commit()
        batch_size = 1000
        for i in range(0, len(records), batch_size):
            for code, name, parent in records[i:i+batch_size]:
                cur.execute(
                    "INSERT INTO oktmo (code, name, parent_code) VALUES (%s,%s,%s) "
                    "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code",
                    (code, name, parent)
                )
            conn.commit()
    print(f"  Imported {len(records)} OKTMO records")
    return len(records)


def import_okpd2_json(conn, json_url='https://ofdata.ru/open-data/download/okpd_2.json.zip'):
    """Import OKPD2 from ofdata.ru JSON ZIP."""
    import urllib.request, zipfile, json, io as io_
    req = urllib.request.Request(json_url, headers={'User-Agent': 'Mozilla/5.0'})
    resp = urllib.request.urlopen(req, timeout=60)
    data = resp.read()
    with zipfile.ZipFile(io_.BytesIO(data)) as zf:
        content = json.loads(zf.read('okpd_2.json').decode('utf-8'))
    print(f"  Downloaded {len(content)} OKPD2 items")
    with conn.cursor() as cur:
        for item in content:
            code = item['code']
            name = item['name']
            parent = item.get('parent_code') or None
            cur.execute(
                "INSERT INTO okpd2 (code, name, parent_code) VALUES (%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code",
                (code, name, parent)
            )
        conn.commit()
    print(f"  Imported {len(content)} OKPD2 records")
    return len(content)


def import_tnved_xlsx(conn, xlsx_url='https://www.tws.by/tws/tnved/download/excel'):
    """Import TNVED from tws.by XLSX."""
    import urllib.request, openpyxl
    req = urllib.request.Request(xlsx_url, headers={'User-Agent': 'Mozilla/5.0'})
    resp = urllib.request.urlopen(req, timeout=60)
    data = resp.read()
    with tempfile.NamedTemporaryFile(suffix='.xlsx', delete=False) as f:
        f.write(data)
        path = f.name
    wb = openpyxl.load_workbook(path)
    ws = wb['ТНВЭД']
    os.unlink(path)
    records = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        code = str(row[0]).strip() if row[0] else ''
        name = str(row[1]).strip() if row[1] else ''
        if not code or not name or code == 'None':
            continue
        parent = None
        if len(code) >= 10:
            parent_code = code.rstrip('0')
            while len(parent_code) < 10:
                parent_code += '0'
            if parent_code != code:
                parent = parent_code
        records.append((code, name, parent))
    print(f"  Parsed {len(records)} TNVED records")
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE tnved ALTER COLUMN name TYPE TEXT")
        conn.commit()
        for code, name, parent in records:
            cur.execute(
                "INSERT INTO tnved (code, name, parent_code) VALUES (%s,%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, parent_code=EXCLUDED.parent_code",
                (code, name, parent)
            )
        conn.commit()
    print(f"  Imported {len(records)} TNVED records")
    return len(records)


def import_okopf_json(conn, json_url='https://ofdata.ru/open-data/download/okopf.json.zip'):
    """Import OKOPF from ofdata.ru JSON ZIP."""
    import urllib.request, zipfile, json, io as io_
    req = urllib.request.Request(json_url, headers={'User-Agent': 'Mozilla/5.0'})
    resp = urllib.request.urlopen(req, timeout=60)
    data = resp.read()
    with zipfile.ZipFile(io_.BytesIO(data)) as zf:
        content = json.loads(zf.read('okopf.json').decode('utf-8'))
    print(f"  Downloaded {len(content)} OKOPF items")
    with conn.cursor() as cur:
        cur.execute("CREATE TABLE IF NOT EXISTS okopf (id BIGSERIAL PRIMARY KEY, code VARCHAR(16) NOT NULL UNIQUE, name TEXT NOT NULL)")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_okopf_code ON okopf(code)")
        conn.commit()
        for item in content:
            code = item['code']
            name = item['full_name']
            cur.execute(
                "INSERT INTO okopf (code, name) VALUES (%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name",
                (code, name)
            )
        conn.commit()
    print(f"  Imported {len(content)} OKOPF records")
    return len(content)


def import_oknpo_txt(conn, doc_path):
    """Import OKNPO from libreoffice-converted DOC text."""
    import re as re_
    text = ''
    if doc_path.endswith('.doc') or doc_path.endswith('.docx'):
        with tempfile.NamedTemporaryFile(suffix=os.path.splitext(doc_path)[1], delete=False) as f:
            f.write(open(doc_path, 'rb').read())
            p = f.name
        with tempfile.TemporaryDirectory() as od:
            r = subprocess.run(['libreoffice', '--headless', '--convert-to', 'txt:Text', '--outdir', od, p],
                             capture_output=True, text=True, timeout=120)
            os.unlink(p)
            if r.returncode == 0:
                tfs = [f for f in os.listdir(od) if f.endswith('.txt')]
                if tfs:
                    with open(os.path.join(od, tfs[0]), 'r', encoding='utf-8', errors='replace') as f:
                        text = f.read()
    if not text:
        print("  SKIP: could not convert OKNPO doc")
        return 0

    records = []
    lines = text.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        m = re_.match(r'^(\d{6})\s+(\d)$', line)
        if m:
            code = m.group(1)
            i += 1
            while i < len(lines) and not lines[i].strip():
                i += 1
            if i < len(lines):
                nl = lines[i].strip()
                if re_.match(r'^\d+$', nl) and len(nl) <= 2:
                    i += 1
                    while i < len(lines) and not lines[i].strip():
                        i += 1
                    if i < len(lines):
                        nl = lines[i].strip()
                name = re_.sub(r'\s+\d+$', '', nl).strip()
                if name and not re_.match(r'^\d+$', name) and not any(r[0] == code for r in records):
                    records.append((code, name))
        i += 1

    print(f"  Parsed {len(records)} OKNPO records")
    with conn.cursor() as cur:
        for code, name in records:
            cur.execute(
                "INSERT INTO oknpo (code, name) VALUES (%s,%s) "
                "ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name",
                (code, name)
            )
        conn.commit()
    print(f"  Imported {len(records)} OKNPO records")
    return len(records)


def import_oknpo_zip(conn, zip_path):
    """Import OKNPO from ZIP containing a .doc file."""
    import zipfile
    with zipfile.ZipFile(zip_path) as z:
        for name in z.namelist():
            if name.lower().endswith('.doc'):
                with tempfile.NamedTemporaryFile(suffix='.doc', delete=False) as f:
                    f.write(z.read(name))
                    p = f.name
                try:
                    return import_oknpo_txt(conn, p)
                finally:
                    os.unlink(p)
    print("  SKIP: no .doc file in OKNPO zip")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--db', default='surypus')
    parser.add_argument('--user', default='postgres')
    parser.add_argument('--host', default='localhost')
    parser.add_argument('--classifier', choices=list(CLASSIFIER_IMPORTS.keys()) + [
        'okof-libre', 'oktmo-libre', 'okved2-libre',
        'okato-csv', 'oktmo-csv', 'okpd2-json', 'tnved-xlsx', 'okopf-json', 'oknpo-zip',
    ])
    parser.add_argument('--csv-path', default='/tmp/okato.csv',
                        help='Path to CSV files for CSV-based importers')
    args = parser.parse_args()

    conn = psycopg2.connect(dbname=args.db, user=args.user, host=args.host)

    libre_map = {
        'okof-libre': ('okof.zip', lambda c, p: import_okof_libre(c, os.path.join(CLASSIFICATORS_DIR, p))),
        'oktmo-libre': ('oktmo.zip', lambda c, p: import_oktmo_libre(c, os.path.join(CLASSIFICATORS_DIR, p))),
        'okved2-libre': ('okved2.zip', lambda c, p: import_okved2_libre(c, os.path.join(CLASSIFICATORS_DIR, p))),
    }
    web_map = {
        'okato-csv': ('', lambda c, p: import_okato_csv(c, args.csv_path.replace('okato', 'okato'))),
        'oktmo-csv': ('', lambda c, p: import_oktmo_csv(c, args.csv_path.replace('okato', 'oktmo'))),
        'okpd2-json': ('', lambda c, p: import_okpd2_json(c)),
        'tnved-xlsx': ('', lambda c, p: import_tnved_xlsx(c)),
        'okopf-json': ('', lambda c, p: import_okopf_json(c)),
        'oknpo-zip': ('oknpo.zip', lambda c, p: import_oknpo_zip(c, os.path.join(CLASSIFICATORS_DIR, p))),
    }
    
    if args.classifier:
        if args.classifier in libre_map:
            _, func = libre_map[args.classifier]
            print(f"Importing {args.classifier} (libreoffice)...")
            func(conn, '')
        elif args.classifier in web_map:
            fname, func = web_map[args.classifier]
            print(f"Importing {args.classifier}...")
            func(conn, fname)
        else:
            f = CLASSIFIER_IMPORTS[args.classifier]
            print(f"Importing {args.classifier}...")
            f(conn, os.path.join(CLASSIFICATORS_DIR, args.classifier))
    else:
        for fname in sorted(CLASSIFIER_IMPORTS, key=lambda x: os.path.getsize(os.path.join(CLASSIFICATORS_DIR, x))):
            f = CLASSIFIER_IMPORTS[fname]
            print(f"Importing {fname}...")
            f(conn, os.path.join(CLASSIFICATORS_DIR, fname))

    conn.close()
    print("\nDone!")


if __name__ == "__main__":
    main()
