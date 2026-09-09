#!/usr/bin/env python3
# SET_REMINDER_V1 — CEO asistanına "bana hatırlat" yeteneği. YENİ TABLO KURMAZ:
# reps için zaten var olan saha_rep_not (Notlarım/Plan) tablosuna yazar. Böylece
# HALİHAZIRDA deploy edilmiş REMINDER_PUSH_V1 zamanlayıcısı o gün push'u atar ve
# hatırlatma Notlarım + Plan takviminde görünür. Tamamen tenant-bağımsız (tenant_id, rep_id).
# 4 düzenleme: (1) _runBrainTool imzasına userId ekle, (2) çağrıda session.userId geçir,
# (3) set_reminder + list_reminders araç tanımları, (4) handler'lar, (5) prompt kuralı.
# Idempotent. /opt/krb-assessment içinde çalıştır.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)

if "SET_REMINDER_V1" in s:
    print("set_reminder: already present, skip all")
    print("DONE.")
    raise SystemExit

# ---------- (1) _runBrainTool imzası: userId parametresi ----------
old_sig = "      async function _runBrainTool(toolName, input, tenantId) {"
new_sig = "      async function _runBrainTool(toolName, input, tenantId, userId) { /* SET_REMINDER_V1 */"
assert s.count(old_sig) == 1, "sig anchor"
s = s.replace(old_sig, new_sig, 1)

# ---------- (2) çağrı yerinde session.userId geçir ----------
old_call = "try { res = await _runBrainTool(tu.name, tu.input, tenantId); }"
new_call = "try { res = await _runBrainTool(tu.name, tu.input, tenantId, session.userId); }"
assert s.count(old_call) == 1, "call anchor"
s = s.replace(old_call, new_call, 1)

# ---------- (3) araç tanımları: create_task'tan ÖNCE ekle ----------
old_def = "        {\n          name: 'create_task',"
new_def = (
    "        {\n"
    "          name: 'set_reminder',\n"
    "          description: 'Kullanıcı bir hatırlatma/anımsatma isterse kullan (\"bana hatırlat\", \"yarın X ara\", \"cuma toplantıyı anımsat\"). "
    "Hatırlatma kullanıcının KENDİ Notlarım/Plan listesine eklenir ve o gün geldiğinde telefonuna push bildirimi gider. "
    "Tarih net değilse tek soruyla netleştir; uydurma.',\n"
    "          input_schema: { type: 'object', properties: {\n"
    "            metin: { type: 'string', description: 'Hatırlatma metni — kısa ve net (ör. \"Mehmet Bey ile fiyat görüşmesi\")' },\n"
    "            tarih: { type: 'string', description: 'Hatırlatma tarihi YYYY-MM-DD. Bugünün tarihi sistem bağlamında verildi; \"yarın\", \"cuma\", \"3 gün sonra\" gibi ifadeleri buna göre hesapla.' }\n"
    "          }, required: ['metin', 'tarih'] }\n"
    "        },\n"
    "        {\n"
    "          name: 'list_reminders',\n"
    "          description: 'Kullanıcının açık (tamamlanmamış) hatırlatmalarını tarih sırasıyla listeler. \"Nelerim var\", \"hatırlatmalarım\", \"listemde ne var\", \"yaklaşan\" gibi sorularda kullan.',\n"
    "          input_schema: { type: 'object', properties: {} }\n"
    "        },\n"
    "        {\n          name: 'create_task',"
)
assert s.count(old_def) == 1, "def anchor"
s = s.replace(old_def, new_def, 1)

# ---------- (4) handler'lar: create_task handler'ından ÖNCE ekle ----------
old_h = "        if (toolName === 'create_task') {"
new_h = (
    "        if (toolName === 'set_reminder') {\n"
    "          if (!userId) return { error: 'kullanici bulunamadi — hatirlatma sahibi belirlenemedi' };\n"
    "          const metin = String((input && (input.metin || input.icerik)) || '').trim();\n"
    "          if (!metin) return { error: 'hatirlatma metni gerekli' };\n"
    "          let d = String((input && (input.tarih || input.remind_at)) || '').trim().slice(0, 10);\n"
    "          if (!/^\\d{4}-\\d{2}-\\d{2}$/.test(d)) return { error: 'tarih YYYY-MM-DD formatinda olmali' };\n"
    "          const _bugun = new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });\n"
    "          if (d < _bugun) return { error: 'tarih gecmiste olamaz (' + d + '); bugun ' + _bugun };\n"
    "          const _r = await query(\n"
    "            \"INSERT INTO saha_rep_not (id, tenant_id, rep_id, icerik, hatirlatma_tarihi) VALUES (gen_random_uuid(), $1, $2, $3, $4) RETURNING id\",\n"
    "            [tenantId, userId, metin, d]\n"
    "          );\n"
    "          return { success: true, id: _r.rows[0].id, tarih: d, message: 'Hatirlatma kuruldu: ' + d + ' — ' + metin + '. O gun telefonuna bildirim gelecek; Notlarim ve Plan ekraninda da gorunur.' };\n"
    "        }\n"
    "        if (toolName === 'list_reminders') {\n"
    "          if (!userId) return { error: 'kullanici bulunamadi' };\n"
    "          const _bugun = new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });\n"
    "          const _r = await query(\n"
    "            \"SELECT to_char(hatirlatma_tarihi,'YYYY-MM-DD') AS tarih, icerik FROM saha_rep_not WHERE tenant_id=$1 AND rep_id=$2 AND tamamlandi=false AND hatirlatma_tarihi IS NOT NULL ORDER BY hatirlatma_tarihi ASC LIMIT 30\",\n"
    "            [tenantId, userId]\n"
    "          );\n"
    "          return { bugun: _bugun, count: _r.rows.length, hatirlatmalar: _r.rows };\n"
    "        }\n"
    "        if (toolName === 'create_task') {"
)
assert s.count(old_h) == 1, "handler anchor"
s = s.replace(old_h, new_h, 1)

# ---------- (5) sistem prompt kurali (3. kuralin arkasina) ----------
old_rule = r"\n3. Görev talebi = hemen create_task kullan."
new_rule = (
    r"\n3. Görev talebi = hemen create_task kullan."
    r"\n3b. Hatırlatma/anımsatma talebinde (\"bana hatırlat\", \"yarın ara\", \"cuma anımsat\") set_reminder kullan — kısa metin + tarih (YYYY-MM-DD); "
    r"o gün kullanıcının telefonuna push gider, Notlarım/Plan ekranında görünür. Tarih net değilse TEK soruyla netleştir. "
    r"\"Nelerim var / hatırlatmalarım / yaklaşan\" denince list_reminders."
)
assert s.count(old_rule) == 1, "prompt rule anchor"
s = s.replace(old_rule, new_rule, 1)

write(FP, s)
print("set_reminder: signature+call+defs+handlers+prompt patched")
print("DONE.")
