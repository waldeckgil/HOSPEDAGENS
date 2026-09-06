-- ============================================================================
-- SCRIPT DE ROLLBACK DEFINITIVO (VOLTA O BANCO AO ESTADO ORIGINAL DE HOJE)
-- ============================================================================

-- 1. Remove Trigger e Funções criadas
DROP TRIGGER IF EXISTS trg_proteger_assinatura ON public.pousadas;
DROP FUNCTION IF EXISTS public.proteger_assinatura_pousada();
DROP FUNCTION IF EXISTS public.is_pousada_ativa(uuid);
DROP FUNCTION IF EXISTS public.is_master_admin();

-- 2. Remove as tabelas novas criadas para o SaaS
DROP TABLE IF EXISTS public.config_sistema CASCADE;
DROP TABLE IF EXISTS public.config_faixas_preco CASCADE;
DROP TABLE IF EXISTS public.planos_saas CASCADE;

-- 3. Remove as colunas novas da tabela pousadas
ALTER TABLE public.pousadas DROP COLUMN IF EXISTS status;
ALTER TABLE public.pousadas DROP COLUMN IF EXISTS data_vencimento;
ALTER TABLE public.pousadas DROP COLUMN IF EXISTS plano_valor;
ALTER TABLE public.pousadas DROP COLUMN IF EXISTS plano_id;

-- 4. RESTAURAÇÃO EXATA DAS POLÍTICAS ORIGINAIS DE POUSADAS
ALTER TABLE public.pousadas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "gestor_ve_e_edita_sua_pousada" ON public.pousadas;
DROP POLICY IF EXISTS "Gerenciamento próprio de pousadas" ON public.pousadas;
DROP POLICY IF EXISTS "Permitir leitura das pousadas" ON public.pousadas;

CREATE POLICY "Gerenciamento próprio de pousadas" ON public.pousadas 
FOR ALL TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY "Permitir leitura das pousadas" ON public.pousadas 
FOR SELECT TO authenticated USING (id = auth.uid());

-- 5. RESTAURAÇÃO EXATA DAS POLÍTICAS ORIGINAIS DE SUITES
ALTER TABLE public.suites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "leitura_suites_regras" ON public.suites;
DROP POLICY IF EXISTS "escrita_suites_regras" ON public.suites;
DROP POLICY IF EXISTS "Gerenciamento próprio de suites" ON public.suites;
DROP POLICY IF EXISTS "Permitir editar suites do dono" ON public.suites;
DROP POLICY IF EXISTS "Permitir leitura publica de suites" ON public.suites;
DROP POLICY IF EXISTS "Permitir visualizar suites do dono" ON public.suites;

CREATE POLICY "Gerenciamento próprio de suites" ON public.suites 
FOR ALL TO authenticated USING (pousada_id = auth.uid()) WITH CHECK (pousada_id = auth.uid());

CREATE POLICY "Permitir editar suites do dono" ON public.suites 
FOR ALL TO authenticated USING (pousada_id = auth.uid()) WITH CHECK (pousada_id = auth.uid());

CREATE POLICY "Permitir leitura publica de suites" ON public.suites 
FOR SELECT TO public USING (true);

CREATE POLICY "Permitir visualizar suites do dono" ON public.suites 
FOR SELECT TO authenticated USING (pousada_id = auth.uid());

-- 6. RESTAURAÇÃO EXATA DAS POLÍTICAS ORIGINAIS DE RESERVAS
ALTER TABLE public.reservas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "leitura_reservas_regras" ON public.reservas;
DROP POLICY IF EXISTS "insercao_reservas_regras" ON public.reservas;
DROP POLICY IF EXISTS "insercao_vitrine_regras" ON public.reservas;
DROP POLICY IF EXISTS "gestao_reservas_regras" ON public.reservas;
DROP POLICY IF EXISTS "Gestor pode gerenciar reservas" ON public.reservas;
DROP POLICY IF EXISTS "Permitir insercao publica de reservas pendentes" ON public.reservas;
DROP POLICY IF EXISTS "Permitir inserção pública de reservas" ON public.reservas;

CREATE POLICY "Gestor pode gerenciar reservas" ON public.reservas 
FOR ALL TO authenticated USING (pousada_id = auth.uid()) WITH CHECK (pousada_id = auth.uid());

CREATE POLICY "Permitir insercao publica de reservas pendentes" ON public.reservas 
FOR INSERT TO public WITH CHECK (status = 'Pendente'::text);

CREATE POLICY "Permitir inserção pública de reservas" ON public.reservas 
FOR INSERT TO anon, authenticated WITH CHECK (true);

-- 7. RESTAURAÇÃO EXATA DAS POLÍTICAS ORIGINAIS DE TARIFAS ESPECIAIS
ALTER TABLE public.tarifas_especiais ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "leitura_tarifas_regras" ON public.tarifas_especiais;
DROP POLICY IF EXISTS "escrita_tarifas_regras" ON public.tarifas_especiais;
DROP POLICY IF EXISTS "Gestor gerencia tarifas especiais" ON public.tarifas_especiais;
DROP POLICY IF EXISTS "Leitura pública de tarifas especiais" ON public.tarifas_especiais;

CREATE POLICY "Gestor gerencia tarifas especiais" ON public.tarifas_especiais 
FOR ALL TO public USING (pousada_id = auth.uid()) WITH CHECK (pousada_id = auth.uid());

CREATE POLICY "Leitura pública de tarifas especiais" ON public.tarifas_especiais 
FOR SELECT TO public USING (true);