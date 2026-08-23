// Utiliza a mesma instância padronizada do Supabase
const SUPABASE_URL = 'https://evrkniykafvydnhxycit.supabase.co';
const SUPABASE_KEY = 'sb_publishable_TCHdTjTVsu652onrjqjptw_RUCJaqTs';
const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

async function carregarDashboard() {
    // 1. Valida a sessão atual antes de buscar os dados
    const { data: { session }, error: sessionError } = await supabaseClient.auth.getSession();
    
    if (sessionError || !session) {
        console.warn("Usuário não autenticado. Redirecionando para o login...");
        window.location.href = 'index.html';
        return;
    }

    const usuarioIdAtual = session.user.id;

    // 2. Busca as suítes filtrando estritamente pela pousada do usuário logado
    const { data: suites, error } = await supabaseClient
        .from('suites')
        .select('*')
        .eq('pousada_id', usuarioIdAtual);

    if (error) { 
        console.error("Erro ao carregar suítes:", error); 
        return; 
    }

    const container = document.getElementById('suites-container');
    if (!container) return;
    
    container.innerHTML = ''; // Limpa o conteúdo anterior

    if (!suites || suites.length === 0) {
        container.innerHTML = `<p class="text-gray-500 italic p-4">Nenhuma suíte cadastrada ainda.</p>`;
        return;
    }

    suites.forEach(suite => {
        // Lógica de cores baseada no status
        const classes = {
            'Pendente': 'bg-yellow-200 border-yellow-500',
            'Ocupada': 'bg-gray-300 border-gray-600',
            'Disponível': 'bg-green-200 border-green-500',
            'Limpeza': 'bg-red-200 border-red-500'
        };

        const statusClasse = classes[suite.status] || 'bg-gray-100 border-gray-400';

        const card = `
            <div class="p-6 rounded-lg shadow-md border-l-8 ${statusClasse}">
                <h2 class="text-xl font-bold">${suite.nome || 'Suíte'}</h2>
                <p class="text-sm mt-2">Status: <strong>${suite.status || 'Disponível'}</strong></p>
                <button class="mt-4 px-4 py-2 rounded text-white ${suite.status === 'Ocupada' ? 'bg-gray-600' : 'bg-blue-600'}">
                    ${suite.status === 'Ocupada' ? 'Indisponível' : 'Gerenciar'}
                </button>
            </div>
        `;
        container.innerHTML += card;
    });
}

// Executa a função ao carregar o script
carregarDashboard();