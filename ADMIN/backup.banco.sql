-- ============================================================================
-- BACKUP DE SEGURANÇA (CLONE DOS DADOS ATUAIS)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.backup_pousadas AS SELECT * FROM public.pousadas;
CREATE TABLE IF NOT EXISTS public.backup_suites AS SELECT * FROM public.suites;
CREATE TABLE IF NOT EXISTS public.backup_reservas AS SELECT * FROM public.reservas;
CREATE TABLE IF NOT EXISTS public.backup_tarifas_especiais AS SELECT * FROM public.tarifas_especiais;