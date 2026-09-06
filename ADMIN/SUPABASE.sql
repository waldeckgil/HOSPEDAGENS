-- ============================================================================
-- 1. TABELA DE CONFIGURAÇÕES GERAIS (LEMBRETES DE VENCIMENTO)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.config_sistema (
    id int PRIMARY KEY DEFAULT 1,
    dias_aviso_vencimento int DEFAULT 5
);

INSERT INTO public.config_sistema (id, dias_aviso_vencimento) 
VALUES (1, 5) 
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 2. TABELA DE PREÇOS POR FAIXA DE SUÍTES (USADA NO ADMIN E EM TARIFAS)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.config_faixas_preco (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    min_suites int NOT NULL,
    max_suites int, -- NULL = ilimitado
    valor_mensal numeric(10,2) NOT NULL,
    descricao text
);

INSERT INTO public.config_faixas_preco (min_suites, max_suites, valor_mensal, descricao) 
SELECT 1, 10, 149.90, 'Até 10 suítes'
WHERE NOT EXISTS (SELECT 1 FROM public.config_faixas_preco);

INSERT INTO public.config_faixas_preco (min_suites, max_suites, valor_mensal, descricao) 
SELECT 11, NULL, 249.90, 'Acima de 10 suítes'
WHERE NOT EXISTS (SELECT 1 FROM public.config_faixas_preco WHERE min_suites = 11);

-- ============================================================================
-- 3. NOVOS CAMPOS NA TABELA POUSADAS
-- ============================================================================
ALTER TABLE public.pousadas ADD COLUMN IF NOT EXISTS status text DEFAULT 'active' CHECK (status IN ('pending', 'active', 'blocked'));
ALTER TABLE public.pousadas ADD COLUMN IF NOT EXISTS data_vencimento date DEFAULT (CURRENT_DATE + INTERVAL '30 days');
ALTER TABLE public.pousadas ADD COLUMN IF NOT EXISTS plano_valor numeric(10,2) DEFAULT 149.90;

-- GARANTE QUE AS POUSADAS JÁ EXISTENTES CONTINUEM ATIVAS E COM 30 DIAS DE PRAZO:
UPDATE public.pousadas 
SET status = 'active', 
    data_vencimento = COALESCE(data_vencimento, CURRENT_DATE + INTERVAL '30 days'),
    plano_valor = COALESCE(plano_valor, 149.90)
WHERE status IS NULL OR status = 'pending';

-- ============================================================================
-- 4. FUNÇÕES DE SEGURANÇA (SECURITY DEFINER)
-- ============================================================================

-- Identifica se o usuário atual é o Administrador Master da plataforma
CREATE OR REPLACE FUNCTION public.is_master_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT (auth.jwt()->>'email' = 'waldeckgil@gmail.com');
$$;

-- Verifica se a pousada está liberada para operar reservas e suítes
CREATE OR REPLACE FUNCTION public.is_pousada_ativa(pid uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.pousadas 
        WHERE id = pid 
          AND status = 'active'
          AND (data_vencimento IS NULL OR data_vencimento >= (CURRENT_DATE - INTERVAL '2 days')) -- 2 dias de tolerância
    );
$$;

-- ============================================================================
-- 5. TRIGGER ANTI-FRAUDE (IMPEDE O GESTOR DE SE AUTO-DESBLOQUEAR)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.proteger_assinatura_pousada()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT public.is_master_admin() THEN
        NEW.status := OLD.status;
        NEW.data_vencimento := OLD.data_vencimento;
        NEW.plano_valor := OLD.plano_valor;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_assinatura ON public.pousadas;
CREATE TRIGGER trg_proteger_assinatura
BEFORE UPDATE ON public.pousadas
FOR EACH ROW EXECUTE FUNCTION public.proteger_assinatura_pousada();

-- ============================================================================
-- 6. POLÍTICAS RLS (SEGURANÇA E BLOQUEIO SOFT COMPATÍVEIS)
-- ============================================================================

-- A) CONFIG_SISTEMA
ALTER TABLE public.config_sistema ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leitura config sistema" ON public.config_sistema;
CREATE POLICY "Leitura config sistema" ON public.config_sistema FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Master edita config sistema" ON public.config_sistema;
CREATE POLICY "Master edita config sistema" ON public.config_sistema FOR ALL TO authenticated 
USING (public.is_master_admin()) 
WITH CHECK (public.is_master_admin());

-- B) CONFIG_FAIXAS_PRECO
ALTER TABLE public.config_faixas_preco ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leitura faixas preco" ON public.config_faixas_preco;
CREATE POLICY "Leitura faixas preco" ON public.config_faixas_preco FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Master edita faixas preco" ON public.config_faixas_preco;
CREATE POLICY "Master edita faixas preco" ON public.config_faixas_preco FOR ALL TO authenticated 
USING (public.is_master_admin()) 
WITH CHECK (public.is_master_admin());

-- C) POUSADAS (Gestor edita e lê a sua própria normalmente)
ALTER TABLE public.pousadas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Gerenciamento próprio de pousadas" ON public.pousadas;
DROP POLICY IF EXISTS "Permitir leitura das pousadas" ON public.pousadas;
DROP POLICY IF EXISTS "gestor_ve_e_edita_sua_pousada" ON public.pousadas;

CREATE POLICY "gestor_ve_e_edita_sua_pousada" ON public.pousadas
FOR ALL TO authenticated
USING (id = auth.uid() OR public.is_master_admin())
WITH CHECK (id = auth.uid() OR public.is_master_admin());

-- D) SUITES (Gestor lê e edita as suas normalmente enquanto ativa)
ALTER TABLE public.suites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Gerenciamento próprio de suites" ON public.suites;
DROP POLICY IF EXISTS "Permitir editar suites do dono" ON public.suites;
DROP POLICY IF EXISTS "Permitir leitura publica de suites" ON public.suites;
DROP POLICY IF EXISTS "Permitir visualizar suites do dono" ON public.suites;
DROP POLICY IF EXISTS "leitura_suites_regras" ON public.suites;
DROP POLICY IF EXISTS "escrita_suites_regras" ON public.suites;

CREATE POLICY "leitura_suites_regras" ON public.suites 
FOR SELECT USING (pousada_id = auth.uid() OR public.is_master_admin() OR ativa = true);

CREATE POLICY "escrita_suites_regras" ON public.suites 
FOR ALL TO authenticated 
USING (public.is_master_admin() OR (pousada_id = auth.uid() AND public.is_pousada_ativa(pousada_id)))
WITH CHECK (public.is_master_admin() OR (pousada_id = auth.uid() AND public.is_pousada_ativa(pousada_id)));

-- E) RESERVAS (Permite vitrine inserir Pendente E gestor inserir qualquer status no Dashboard)
ALTER TABLE public.reservas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Gestor pode gerenciar reservas" ON public.reservas;
DROP POLICY IF EXISTS "Permitir insercao publica de reservas pendentes" ON public.reservas;
DROP POLICY IF EXISTS "Permitir inserção pública de reservas" ON public.reservas;
DROP POLICY IF EXISTS "leitura_reservas_regras" ON public.reservas;
DROP POLICY IF EXISTS "insercao_vitrine_regras" ON public.reservas;
DROP POLICY IF EXISTS "insercao_reservas_regras" ON public.reservas;
DROP POLICY IF EXISTS "gestao_reservas_regras" ON public.reservas;

CREATE POLICY "leitura_reservas_regras" ON public.reservas 
FOR SELECT TO authenticated 
USING (pousada_id = auth.uid() OR public.is_master_admin());

-- Permite hóspedes inserirem 'Pendente' E gestores da pousada inserirem qualquer reserva
CREATE POLICY "insercao_reservas_regras" ON public.reservas 
FOR INSERT TO public 
WITH CHECK (
    public.is_pousada_ativa(pousada_id) 
    AND (pousada_id = auth.uid() OR status = 'Pendente' OR public.is_master_admin())
);

CREATE POLICY "gestao_reservas_regras" ON public.reservas 
FOR UPDATE TO authenticated 
USING (public.is_master_admin() OR (pousada_id = auth.uid() AND public.is_pousada_ativa(pousada_id)))
WITH CHECK (public.is_master_admin() OR (pousada_id = auth.uid() AND public.is_pousada_ativa(pousada_id)));

-- F) TARIFAS ESPECIAIS
ALTER TABLE public.tarifas_especiais ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Gestor gerencia tarifas especiais" ON public.tarifas_especiais;
DROP POLICY IF EXISTS "Leitura pública de tarifas especiais" ON public.tarifas_especiais;
DROP POLICY IF EXISTS "leitura_tarifas_regras" ON public.tarifas_especiais;
DROP POLICY IF EXISTS "escrita_tarifas_regras" ON public.tarifas_especiais;

CREATE POLICY "leitura_tarifas_regras" ON public.tarifas_especiais FOR SELECT USING (true);

CREATE POLICY "escrita_tarifas_regras" ON public.tarifas_especiais 
FOR ALL TO authenticated 
USING (public.is_master_admin() OR (pousada_id = auth.uid() AND public.is_pousada_ativa(pousada_id)))
WITH CHECK (public.is_master_admin() OR (pousada_id = auth.uid() AND public.is_pousada_ativa(pousada_id)));