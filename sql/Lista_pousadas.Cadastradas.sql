SELECT 
    p.nome AS nome_pousada,
    u.email AS email_gestor,
    COUNT(s.id) AS total_suites,
    STRING_AGG(s.nome, ', ') AS lista_suites
FROM public.pousadas p
JOIN auth.users u ON p.id = u.id
LEFT JOIN public.suites s ON p.id = s.pousada_id
GROUP BY p.id, p.nome, u.email
ORDER BY p.nome;