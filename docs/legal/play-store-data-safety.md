# Play Store — Data Safety form (rascunho de respostas)

Respostas sugeridas para o formulário "Data Safety" da Google Play Console (app PocketExpenses).

## 1. Dados recolhidos

| Tipo de dado | Recolhido? | Partilhado? | Encriptado em trânsito? | Pode o utilizador apagar? |
|---|---|---|---|---|
| **Localização aproximada** | Não | — | — | — |
| **Localização precisa** | Não | — | — | — |
| **Endereço de email** | Sim | Não | Sim | Sim (eliminar conta) |
| **Nome** | Sim | Não | Sim | Sim (editar/eliminar conta) |
| **ID de utilizador** | Sim | Não | Sim | Sim (eliminar conta) |
| **Histórico de compras** | Sim (plano/subscrição) | Não | Sim | Sim (eliminar conta) |
| **Fotos** | Não | — | — | — |
| **Áudio** | Não | — | — | — |
| **Vídeos** | Não | — | — | — |
| **Ficheiros e documentos** | Não | — | — | — |
| **Atividade em apps** (interações com conteúdo) | Não | — | — | — |
| **Atividade de navegação web** | Não | — | — | — |
| **Diagnóstico** (crash logs) | Sim (se configurado) | Não | Sim | N/A |
| **Identificadores de dispositivo** | Sim (se telemetria configurada) | Não | Sim | N/A |

## 2. Finalidade dos dados

- **Endereço de email / nome / ID de utilizador**: criação e gestão de conta, autenticação.
- **Histórico de compras (plano)**: gestão do plano Premium/Founder.
- **Diagnóstico**: análise de falhas e melhoria da estabilidade.

## 3. Práticas de segurança

- [x] Os dados são encriptados em trânsito (TLS/HTTPS).
- [x] Existe mecanismo para o utilizador pedir eliminação dos dados (eliminar conta na app).
- [ ] Os dados são encriptados em repouso (na BD: encriptação do lado do fornecedor — verificar com Supabase se aplicável).
- [ ] É possível pedir exportação dos dados (não implementado — opcional, ver nota).

## 4. Notas

- **Login com Google**: se usares "Entrar com Google", a Google Play considerará que o serviço recolhe dados de conta via Google Sign-In — é preciso declarar email/nome e marcar como partilhados com a Google? **Não** — os dados não são partilhados com terceiros; apenas recebidos do fornecedor de identidade. Declarar no campo de descrição.
- **Idade**: a app não é direcionada a menores de 13 anos. Existe confirmação de idade ≥16 anos no registo.
- **Exportação de dados (portabilidade, art. 20.º RGPD)**: ainda não implementada na app — recomendado adicionar opção "Exportar dados" (JSON/CSV) para responder a pedidos de portabilidade.

## Checklist final antes de submeter

- [ ] Verificar que a app não envia dados para Google Ads/Firebase Analytics (se não usado, não declarar).
- [ ] Declarar a página de Política de Privacidade ativa e acessível (URL público).
- [ ] Garantir que a Política de Privacidade e os Termos estão publicados e sem 404.
