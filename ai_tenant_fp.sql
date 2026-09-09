-- AI_TENANT_KANON_V1 fingerprint. Konteyner marker=3 + uuid=0 DOGRULANDIKTAN SONRA calistir.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AI_TENANT_KANON_V1',
 'AI text-to-SQL prompt''larindaki gomulu KRB tenant literali kaldirildi (3 yer): IT_AGENT_TOOLS.execute_query description + input_schema sql desc + buildDeptSystemPrompt deptExtra.it "Tenant:" satiri. Artik LLM''e "WHERE tenant_id=$1" dedirtiyor; executeQueryTool $1''i session.tenantId ile degistiriyor. dept context tenant''i session.tenantId''den dinamik.',
 'Cok-tenant supurme (hardcode_tenant_sweep.sql) tek kalan hardcode''u buldu: 2 AI-prompt tenant literali (dashboard degil, dept-chat/IT-ajani text-to-SQL). 2. tenant orada finansal soru sorarsa LLM KRB literaliyle filtreleyip KRB verisi okurdu. Fatih ilkesi: tek hardcoded sayi bile olmasin. KRB davranisi degismedi (session.tenantId zaten KRB).',
 '{"yer":["IT_AGENT_TOOLS.execute_query.description","IT_AGENT_TOOLS.execute_query.input_schema.sql","buildDeptSystemPrompt deptExtra.it"],"onceki":"literal f8a5d20f...","yeni":"$1 (executeQueryTool session.tenantId enjekte) + dept context session.tenantId","marker":"AI_TENANT_KANON_V1","dogrulama":"server_container.mjs KRB uuid literal=0","kaynak_denetim":"hardcode_tenant_sweep.sql"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AI_TENANT_KANON_V1');

SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='AI_TENANT_KANON_V1';
