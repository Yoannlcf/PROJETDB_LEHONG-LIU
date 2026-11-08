-- =============================================================================
-- 4_interrogation.sql — Requêtes du scénario d'utilisation
-- Mini-projet TI503N — Partie 2, étape V
--
-- Scénario : la responsable des opérations cloud prépare la revue trimestrielle
-- de novembre 2026. Elle doit présenter à la direction :
--   A. l'état du parc et la capacité disponible (centres, serveurs, VM) ;
--   B. le portefeuille clients (abonnements, ressources consommées) ;
--   C. la qualité de service (tickets de support).
-- Le scénario complet est décrit dans le README.
-- =============================================================================

USE cloud_provider;

-- =============================================================================
-- 1. PROJECTIONS ET SÉLECTIONS (tri, DISTINCT, masques, IN, BETWEEN)
-- =============================================================================

-- 1.1 [A] Centres de données situés dans l'Union européenne, du plus puissant
--     au moins puissant (IN + tri).
SELECT id_centre, ville_centre, pays_centre, capacite_mw_centre
FROM centre_de_donnees
WHERE pays_centre IN ('France', 'Allemagne', 'Pays-Bas', 'Irlande')
ORDER BY capacite_mw_centre DESC;

-- 1.2 [A] Catalogue des systèmes d'exploitation réellement déployés, sans
--     doublon (DISTINCT + tri).
SELECT DISTINCT os_machine
FROM machine_virtuelle
ORDER BY os_machine;

-- 1.3 [A] VM Windows non exposées sur Internet : candidates à un accès par
--     bastion plutôt que par IP publique (masque LIKE + IS NULL).
SELECT id_machine, hote_machine, os_machine, ip_privee_machine
FROM machine_virtuelle
WHERE os_machine LIKE 'Windows Server%'
  AND ip_publique_machine IS NULL
ORDER BY hote_machine;

-- 1.4 [C] Tickets de priorité Haute ou Critique ouverts pendant le trimestre
--     (août à octobre 2026), du plus récent au plus ancien (BETWEEN + IN).
SELECT id_ticket, date_ouverture_ticket, priorite_resolution_ticket, statut_ticket
FROM ticket_support
WHERE date_ouverture_ticket BETWEEN '2026-08-01 00:00:00' AND '2026-10-31 23:59:59'
  AND priorite_resolution_ticket IN ('Haute', 'Critique')
ORDER BY date_ouverture_ticket DESC;

-- 1.5 [B] Clients français, repérés par le domaine de leur adresse de contact
--     (masque LIKE), par ordre alphabétique.
SELECT id_client, nom_entreprise, mail_client
FROM client
WHERE mail_client LIKE '%.fr'
ORDER BY nom_entreprise;

-- 1.6 [A] Serveurs à forte capacité mémoire (512 Go à 1 To) : ceux qui
--     peuvent accueillir de grosses VM (BETWEEN + double tri).
SELECT id_serveur, id_centre, ram_totale_go_serveur, cpu_total_serveur
FROM serveur_physique
WHERE ram_totale_go_serveur BETWEEN 512 AND 1024
ORDER BY ram_totale_go_serveur DESC, cpu_total_serveur DESC;

-- =============================================================================
-- 2. FONCTIONS D'AGRÉGATION (GROUP BY, HAVING)
-- =============================================================================

-- 2.1 [A] Pour chaque centre : nombre de serveurs, RAM et cœurs installés.
SELECT id_centre,
       COUNT(*)                   AS nb_serveurs,
       SUM(ram_totale_go_serveur) AS ram_installee_go,
       SUM(cpu_total_serveur)     AS coeurs_installes
FROM serveur_physique
GROUP BY id_centre
ORDER BY ram_installee_go DESC;

-- 2.2 [A] Serveurs dont plus de 80 % de la RAM est déjà allouée aux VM :
--     risque de saturation à anticiper (agrégat + HAVING sur un calcul).
SELECT s.id_serveur, s.id_centre, s.ram_totale_go_serveur,
       SUM(v.ram_go_machine) AS ram_allouee_go,
       ROUND(100 * SUM(v.ram_go_machine) / s.ram_totale_go_serveur, 1) AS taux_occupation
FROM serveur_physique s
JOIN machine_virtuelle v ON v.id_serveur = s.id_serveur
GROUP BY s.id_serveur, s.id_centre, s.ram_totale_go_serveur
HAVING SUM(v.ram_go_machine) > 0.8 * s.ram_totale_go_serveur
ORDER BY taux_occupation DESC;

-- 2.3 [C] Répartition des tickets par priorité et par statut.
SELECT priorite_resolution_ticket, statut_ticket, COUNT(*) AS nb_tickets
FROM ticket_support
GROUP BY priorite_resolution_ticket, statut_ticket
ORDER BY FIELD(priorite_resolution_ticket, 'Critique', 'Haute', 'Normale', 'Basse'),
         nb_tickets DESC;

-- 2.4 [C] Clients ayant ouvert au moins 5 tickets : comptes à suivre de près.
SELECT id_client, COUNT(*) AS nb_tickets,
       SUM(priorite_resolution_ticket = 'Critique') AS dont_critiques
FROM ticket_support
GROUP BY id_client
HAVING COUNT(*) >= 5
ORDER BY nb_tickets DESC;

-- 2.5 [B] Bases managées par moteur : nombre, stockage total et moyen,
--     pour les moteurs utilisés au moins 4 fois.
SELECT moteur_bd, COUNT(*) AS nb_bases,
       SUM(stockage_bd) AS stockage_total_go,
       ROUND(AVG(stockage_bd)) AS stockage_moyen_go
FROM base_de_donnees
GROUP BY moteur_bd
HAVING COUNT(*) >= 4
ORDER BY stockage_total_go DESC;

-- 2.6 [A] Par système d'exploitation : nombre de VM, vCPU moyens,
--     RAM minimale et maximale allouée.
SELECT os_machine, COUNT(*) AS nb_vm,
       ROUND(AVG(vcpu_machine), 1) AS vcpu_moyen,
       MIN(ram_go_machine) AS ram_min_go, MAX(ram_go_machine) AS ram_max_go
FROM machine_virtuelle
GROUP BY os_machine
ORDER BY nb_vm DESC;

-- =============================================================================
-- 3. JOINTURES (internes, externes, multiples, auto-jointure)
-- =============================================================================

-- 3.1 [B] Jointure multiple (5 tables) : pour chaque VM, le client qui la
--     paie et la ville du centre où elle tourne.
SELECT c.nom_entreprise, a.niveau_abonnement, v.hote_machine,
       v.vcpu_machine, v.ram_go_machine, ce.ville_centre
FROM machine_virtuelle v
JOIN abonnement        a  ON a.id_abonnement = v.id_abonnement
JOIN client            c  ON c.id_client     = a.id_client
JOIN serveur_physique  s  ON s.id_serveur    = v.id_serveur
JOIN centre_de_donnees ce ON ce.id_centre    = s.id_centre
ORDER BY c.nom_entreprise, v.hote_machine;

-- 3.2 [A] Jointure externe gauche : serveurs physiques sur lesquels aucune
--     VM n'est déployée (capacité immédiatement disponible).
SELECT s.id_serveur, s.id_centre, s.ram_totale_go_serveur, s.cpu_total_serveur
FROM serveur_physique s
LEFT JOIN machine_virtuelle v ON v.id_serveur = s.id_serveur
WHERE v.id_machine IS NULL
ORDER BY s.ram_totale_go_serveur DESC;

-- 3.3 [C] Jointure externe gauche + agrégat : tous les clients avec leur
--     nombre de tickets, y compris ceux qui n'en ont aucun (0).
SELECT c.id_client, c.nom_entreprise, COUNT(t.id_ticket) AS nb_tickets
FROM client c
LEFT JOIN ticket_support t ON t.id_client = c.id_client
GROUP BY c.id_client, c.nom_entreprise
ORDER BY nb_tickets DESC, c.nom_entreprise;

-- 3.4 [B] Jointure externe droite : tous les abonnements avec leurs bases
--     managées éventuelles (NULL si l'abonnement n'en contient aucune).
SELECT a.id_abonnement, a.niveau_abonnement, b.nom_bd, b.moteur_bd
FROM base_de_donnees b
RIGHT JOIN abonnement a ON a.id_abonnement = b.id_abonnement
ORDER BY a.id_abonnement;

-- 3.5 [A] Auto-jointure : paires de serveurs d'un même centre ayant le même
--     gabarit (RAM et cœurs), interchangeables pour une migration à chaud.
SELECT s1.id_centre, s1.id_serveur AS serveur_1, s2.id_serveur AS serveur_2,
       s1.ram_totale_go_serveur, s1.cpu_total_serveur
FROM serveur_physique s1
JOIN serveur_physique s2
  ON  s2.id_centre             = s1.id_centre
  AND s2.ram_totale_go_serveur = s1.ram_totale_go_serveur
  AND s2.cpu_total_serveur     = s1.cpu_total_serveur
  AND s2.id_serveur            > s1.id_serveur        -- évite (a,b) et (b,a)
ORDER BY s1.id_centre;

-- 3.6 [C] Tickets critiques encore non résolus, avec le contact du client
--     et le niveau de service de l'abonnement concerné.
SELECT t.id_ticket, t.date_ouverture_ticket, t.statut_ticket,
       c.nom_entreprise, c.mail_client, c.num_tel_client, a.niveau_abonnement
FROM ticket_support t
INNER JOIN client     c ON c.id_client     = t.id_client
INNER JOIN abonnement a ON a.id_abonnement = t.id_abonnement
WHERE t.priorite_resolution_ticket = 'Critique'
  AND t.statut_ticket NOT IN ('Résolu', 'Fermé')
ORDER BY t.date_ouverture_ticket;

-- =============================================================================
-- 4. REQUÊTES IMBRIQUÉES ((NOT) IN, (NOT) EXISTS, ANY, ALL, corrélées)
-- =============================================================================

-- 4.1 [C] NOT EXISTS : clients qui n'ont jamais ouvert de ticket.
SELECT c.id_client, c.nom_entreprise
FROM client c
WHERE NOT EXISTS (SELECT 1 FROM ticket_support t WHERE t.id_client = c.id_client)
ORDER BY c.nom_entreprise;

-- 4.2 [B] IN imbriqués : clients dont au moins une VM tourne en France
--     (données soumises au droit français, pour la conformité).
SELECT id_client, nom_entreprise
FROM client
WHERE id_client IN (
    SELECT a.id_client FROM abonnement a
    WHERE a.id_abonnement IN (
        SELECT v.id_abonnement FROM machine_virtuelle v
        WHERE v.id_serveur IN (
            SELECT s.id_serveur FROM serveur_physique s
            WHERE s.id_centre IN (SELECT id_centre FROM centre_de_donnees
                                  WHERE pays_centre = 'France'))))
ORDER BY nom_entreprise;

-- 4.3 [B] NOT IN : abonnements actifs sans aucune ressource (ni VM, ni base
--     managée) — clients à relancer.
SELECT a.id_abonnement, a.date_debut_abonnement, a.niveau_abonnement, a.id_client
FROM abonnement a
WHERE a.id_abonnement NOT IN (SELECT id_abonnement FROM machine_virtuelle)
  AND a.id_abonnement NOT IN (SELECT id_abonnement FROM base_de_donnees)
ORDER BY a.date_debut_abonnement;

-- 4.4 [A] ALL : le ou les serveurs ayant la plus grande RAM du parc.
SELECT id_serveur, id_centre, ram_totale_go_serveur
FROM serveur_physique
WHERE ram_totale_go_serveur >= ALL (SELECT ram_totale_go_serveur FROM serveur_physique);

-- 4.5 [A] ANY : centres dont la capacité électrique dépasse celle d'au
--     moins un centre français.
SELECT id_centre, ville_centre, capacite_mw_centre
FROM centre_de_donnees
WHERE capacite_mw_centre > ANY (SELECT capacite_mw_centre FROM centre_de_donnees
                                WHERE pays_centre = 'France')
  AND pays_centre <> 'France'
ORDER BY capacite_mw_centre DESC;

-- 4.6 [A] Sous-requête corrélée : VM qui consomment plus de RAM que la
--     moyenne des VM de leur serveur (candidates à un redimensionnement).
SELECT v.id_machine, v.hote_machine, v.id_serveur, v.ram_go_machine
FROM machine_virtuelle v
WHERE v.ram_go_machine > (SELECT AVG(v2.ram_go_machine)
                          FROM machine_virtuelle v2
                          WHERE v2.id_serveur = v.id_serveur)
ORDER BY v.id_serveur, v.ram_go_machine DESC;

-- 4.7 [B] EXISTS : clients ayant un abonnement Premium ou Entreprise ET un
--     ticket critique — priorité absolue pour l'équipe de support.
SELECT c.id_client, c.nom_entreprise
FROM client c
WHERE EXISTS (SELECT 1 FROM abonnement a
              WHERE a.id_client = c.id_client
                AND a.niveau_abonnement IN ('Premium', 'Entreprise'))
  AND EXISTS (SELECT 1 FROM ticket_support t
              WHERE t.id_client = c.id_client
                AND t.priorite_resolution_ticket = 'Critique')
ORDER BY c.nom_entreprise;

-- =============================================================================
-- 5. REQUÊTE ÉTUDIÉE POUR LES PLANS D'EXÉCUTION (voir README)
-- =============================================================================

-- 5.1 [A] Nom d'hôte et système d'exploitation des VM hébergées en France.
--     Algèbre : π hote_machine, os_machine (σ pays_centre='France'
--               (centre_de_donnees ⋈ serveur_physique ⋈ machine_virtuelle))
SELECT v.hote_machine, v.os_machine
FROM centre_de_donnees ce
JOIN serveur_physique  s ON s.id_centre  = ce.id_centre
JOIN machine_virtuelle v ON v.id_serveur = s.id_serveur
WHERE ce.pays_centre = 'France';
