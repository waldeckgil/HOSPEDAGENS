const supabase = supabase.createClient('https://evrkniykafvydnhxycit.supabase.co', 'sb_publishable_TCHdTjTVsu652onrjqjptw_RUCJaqTs');

async function carregarDashboard() {
    const { data: suites, error } = await supabase.from('suites').select('*');

    if (error) { console.error("Erro:", error); return; }

    const container = document.getElementById('suites-container');
    container.innerHTML = ''; // Limpa o que estava estático

    suites.forEach(suite => {
        // Lógica de cores baseada no status
        const classes = {
            'Pendente': 'bg-yellow-200 border-yellow-500',
            'Ocupada': 'bg-gray-300 border-gray-600',
            'Disponível': 'bg-green-200 border-green-500',
            'Limpeza': 'bg-red-200 border-red-500'
        };

        const card = `
            <div class="p-6 rounded-lg shadow-md border-l-8 ${classes[suite.status]}">
                <h2 class="text-xl font-bold">${suite.nome}</h2>
                <p class="text-sm mt-2">Status: <strong>${suite.status}</strong></p>
                <button class="mt-4 px-4 py-2 rounded text-white ${suite.status === 'Ocupada' ? 'bg-gray-600' : 'bg-blue-600'}">
                    ${suite.status === 'Ocupada' ? 'Indisponível' : 'Gerenciar'}
                </button>
            </div>
        `;
        container.innerHTML += card;
    });
}

carregarDashboard();