SELECT 
    p.nome AS nome_pousada,
    s.nome AS nome_suite,
    s.status AS status_suite
FROM 
    pousadas p
JOIN 
    suites s ON p.id = s.pousada_id
ORDER BY 
    p.nome, s.status;