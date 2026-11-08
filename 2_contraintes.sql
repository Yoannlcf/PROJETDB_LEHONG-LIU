-- =============================================================================
-- 2_contraintes.sql — Contraintes de validation (MySQL 8.0.16+ / MariaDB 10.5+)
-- Mini-projet TI503N — Partie 2, étape III.B
--
-- À exécuter après 1_creation.sql. Les cas couverts :
--   1. UNIQUE            : unicité hors clé primaire (simple et composée)
--   2. DEFAULT           : valeurs par défaut
--   3. CHECK ... IN      : domaines de valeurs énumérés
--   4. CHECK ... BETWEEN : bornes numériques et dates
--   5. CHECK ... REGEXP  : formats (e-mail, téléphone, IP, codes)
--   6. CHECK multi-colonnes et combinés (AND / OR / NOT)
--   7. TRIGGER           : règles métier qui portent sur plusieurs tables,
--                          impossibles à exprimer avec un CHECK
--
-- Remarque MySQL : un CHECK ne peut pas porter sur une colonne de clé étrangère
-- dotée d'une action ON DELETE/ON UPDATE, ni utiliser une fonction non
-- déterministe comme CURDATE(). Ces règles passent donc par des triggers.
-- =============================================================================

USE cloud_provider;

-- -----------------------------------------------------------------------------
-- CLIENT
-- -----------------------------------------------------------------------------
ALTER TABLE client
    -- deux clients ne partagent pas la même adresse de contact
    ADD CONSTRAINT uq_client_mail UNIQUE (mail_client),
    -- identifiant sur 8 chiffres exactement (dictionnaire de données)
    ADD CONSTRAINT ck_client_id CHECK (id_client BETWEEN 10000000 AND 99999999),
    -- format d'e-mail : texte@domaine.extension
    ADD CONSTRAINT ck_client_mail
        CHECK (mail_client REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    -- format international : + suivi de 8 à 14 chiffres (E.164)
    ADD CONSTRAINT ck_client_tel CHECK (num_tel_client REGEXP '^\\+[0-9]{8,14}$'),
    -- nom non vide (une chaîne d'espaces passerait NOT NULL)
    ADD CONSTRAINT ck_client_nom CHECK (CHAR_LENGTH(TRIM(nom_entreprise)) >= 2);

-- -----------------------------------------------------------------------------
-- ABONNEMENT
-- -----------------------------------------------------------------------------
ALTER TABLE abonnement
    ALTER COLUMN niveau_abonnement SET DEFAULT 'Standard',
    -- RG02 : niveaux de service proposés
    ADD CONSTRAINT ck_abonnement_niveau
        CHECK (niveau_abonnement IN ('Basique', 'Standard', 'Premium', 'Entreprise')),
    -- identifiant sur 10 chiffres
    ADD CONSTRAINT ck_abonnement_id
        CHECK (id_abonnement BETWEEN 1000000000 AND 9999999999),
    -- pas d'abonnement antérieur au lancement de l'offre cloud
    ADD CONSTRAINT ck_abonnement_date CHECK (date_debut_abonnement >= '2015-01-01');

-- -----------------------------------------------------------------------------
-- BASE DE DONNÉES MANAGÉE
-- -----------------------------------------------------------------------------
ALTER TABLE base_de_donnees
    -- un même abonnement ne contient pas deux bases du même nom (UNIQUE composé)
    ADD CONSTRAINT uq_bd_nom_par_abonnement UNIQUE (id_abonnement, nom_bd),
    -- RG09 : moteurs SQL et NoSQL proposés
    ADD CONSTRAINT ck_bd_moteur
        CHECK (moteur_bd IN ('PostgreSQL', 'MySQL', 'MariaDB', 'SQL Server',
                             'Cosmos DB', 'MongoDB', 'Redis')),
    -- stockage alloué : de 5 Go à 100 To (6 chiffres max)
    ADD CONSTRAINT ck_bd_stockage CHECK (stockage_bd BETWEEN 5 AND 102400),
    -- nom technique : minuscules, chiffres, tirets ou underscores, commence par une lettre
    ADD CONSTRAINT ck_bd_nom CHECK (nom_bd REGEXP '^[a-z][a-z0-9_-]{2,49}$');

-- -----------------------------------------------------------------------------
-- TICKET DE SUPPORT
-- -----------------------------------------------------------------------------
ALTER TABLE ticket_support
    ALTER COLUMN statut_ticket SET DEFAULT 'Ouvert',
    ALTER COLUMN priorite_resolution_ticket SET DEFAULT 'Normale',
    -- RG12 : priorités autorisées
    ADD CONSTRAINT ck_ticket_priorite
        CHECK (priorite_resolution_ticket IN ('Basse', 'Normale', 'Haute', 'Critique')),
    -- RG12 : statuts d'avancement
    ADD CONSTRAINT ck_ticket_statut
        CHECK (statut_ticket IN ('Ouvert', 'En cours', 'En attente client',
                                 'Résolu', 'Fermé')),
    -- une description exploitable par le support
    ADD CONSTRAINT ck_ticket_description CHECK (CHAR_LENGTH(description) >= 10);

-- date d'ouverture par défaut : maintenant
ALTER TABLE ticket_support
    MODIFY date_ouverture_ticket DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- -----------------------------------------------------------------------------
-- CENTRE DE DONNÉES
-- -----------------------------------------------------------------------------
ALTER TABLE centre_de_donnees
    -- code au format PAYS-VILLE-NN, ex. FR-PAR-01 (inspiré des régions Azure)
    ADD CONSTRAINT ck_centre_code CHECK (id_centre REGEXP '^[A-Z]{2}-[A-Z]{3}-[0-9]{2}$'),
    -- capacité électrique réaliste : 1 à 500 MW
    ADD CONSTRAINT ck_centre_capacite CHECK (capacite_mw_centre BETWEEN 1 AND 500);

-- -----------------------------------------------------------------------------
-- SERVEUR PHYSIQUE
-- -----------------------------------------------------------------------------
ALTER TABLE serveur_physique
    -- une IP de gestion n'est attribuée qu'à un seul serveur
    ADD CONSTRAINT uq_serveur_ip UNIQUE (ip_serveur),
    -- réseau de gestion interne : plage privée 10.x.x.x
    ADD CONSTRAINT ck_serveur_ip
        CHECK (ip_serveur REGEXP '^10\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$'),
    -- RAM : de 64 Go à 8 To ; cœurs : de 8 à 512
    ADD CONSTRAINT ck_serveur_ram CHECK (ram_totale_go_serveur BETWEEN 64 AND 8192),
    ADD CONSTRAINT ck_serveur_cpu CHECK (cpu_total_serveur BETWEEN 8 AND 512),
    -- au moins 2 Go de RAM par cœur (contrainte multi-colonnes)
    ADD CONSTRAINT ck_serveur_ratio CHECK (ram_totale_go_serveur >= 2 * cpu_total_serveur);

-- -----------------------------------------------------------------------------
-- MACHINE VIRTUELLE
-- -----------------------------------------------------------------------------
ALTER TABLE machine_virtuelle
    -- un nom d'hôte et une IP publique sont uniques sur toute la plateforme
    -- (UNIQUE accepte plusieurs NULL : les VM sans IP publique restent possibles)
    ADD CONSTRAINT uq_vm_hote UNIQUE (hote_machine),
    ADD CONSTRAINT uq_vm_ip_publique UNIQUE (ip_publique_machine),
    -- RG08 : systèmes d'exploitation du catalogue (masque LIKE)
    ADD CONSTRAINT ck_vm_os
        CHECK (os_machine LIKE 'Windows Server%' OR os_machine LIKE 'Ubuntu%'
            OR os_machine LIKE 'Red Hat%'        OR os_machine LIKE 'Debian%'
            OR os_machine LIKE 'Rocky Linux%'    OR os_machine LIKE 'SUSE%'),
    -- RG08 : ressources allouées (tailles Azure : 1 à 416 vCPU, 1 Go à 4 To)
    ADD CONSTRAINT ck_vm_vcpu CHECK (vcpu_machine BETWEEN 1 AND 416),
    ADD CONSTRAINT ck_vm_ram  CHECK (ram_go_machine BETWEEN 1 AND 4096),
    -- nom d'hôte : lettres minuscules, chiffres et tirets
    ADD CONSTRAINT ck_vm_hote CHECK (hote_machine REGEXP '^[a-z][a-z0-9-]{1,49}$'),
    -- IP privée : plages RFC 1918 (10/8, 172.16/12, 192.168/16)
    ADD CONSTRAINT ck_vm_ip_privee CHECK (
        ip_privee_machine REGEXP '^10\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$'
     OR ip_privee_machine REGEXP '^172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9]{1,3}\\.[0-9]{1,3}$'
     OR ip_privee_machine REGEXP '^192\\.168\\.[0-9]{1,3}\\.[0-9]{1,3}$'),
    -- IP publique : format IPv4 et hors plages privées (NOT)
    ADD CONSTRAINT ck_vm_ip_publique CHECK (
        ip_publique_machine IS NULL
     OR (ip_publique_machine REGEXP '^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$'
         AND NOT (ip_publique_machine LIKE '10.%' OR ip_publique_machine LIKE '192.168.%'))),
    -- les deux adresses d'une VM sont distinctes
    ADD CONSTRAINT ck_vm_ip_distinctes CHECK (ip_publique_machine <> ip_privee_machine);

-- =============================================================================
-- TRIGGERS — règles métier portant sur plusieurs tables
-- SIGNAL SQLSTATE '45000' annule l'insertion ou la modification fautive.
-- =============================================================================

DELIMITER //

-- RG11 : le ticket concerne un abonnement qui appartient au client qui l'ouvre.
-- (Le ticket référence à la fois le client et l'abonnement : sans ce contrôle,
--  un client pourrait ouvrir un ticket sur l'abonnement d'un autre.)
-- On vérifie aussi que le ticket n'est pas antérieur à l'abonnement ni daté
-- dans le futur (CURDATE/NOW sont interdits dans un CHECK).
CREATE TRIGGER trg_ticket_bi BEFORE INSERT ON ticket_support
FOR EACH ROW
BEGIN
    DECLARE v_client INT;
    DECLARE v_debut  DATE;
    SELECT id_client, date_debut_abonnement INTO v_client, v_debut
      FROM abonnement WHERE id_abonnement = NEW.id_abonnement;
    IF v_client <> NEW.id_client THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RG11 : l''abonnement du ticket n''appartient pas à ce client';
    END IF;
    IF DATE(NEW.date_ouverture_ticket) < v_debut THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ticket ouvert avant le début de l''abonnement';
    END IF;
    IF NEW.date_ouverture_ticket > NOW() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La date d''ouverture du ticket est dans le futur';
    END IF;
END//

CREATE TRIGGER trg_ticket_bu BEFORE UPDATE ON ticket_support
FOR EACH ROW
BEGIN
    IF NEW.id_client <> OLD.id_client OR NEW.id_abonnement <> OLD.id_abonnement THEN
        IF (SELECT id_client FROM abonnement
             WHERE id_abonnement = NEW.id_abonnement) <> NEW.id_client THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RG11 : l''abonnement du ticket n''appartient pas à ce client';
        END IF;
    END IF;
END//

-- RG06 / RG08 : l'hyperviseur ne peut pas allouer plus de RAM que le serveur
-- physique n'en possède (somme de la RAM de toutes ses VM).
CREATE TRIGGER trg_vm_bi BEFORE INSERT ON machine_virtuelle
FOR EACH ROW
BEGIN
    DECLARE v_ram_serveur INT;
    DECLARE v_ram_utilisee INT;
    SELECT ram_totale_go_serveur INTO v_ram_serveur
      FROM serveur_physique WHERE id_serveur = NEW.id_serveur;
    SELECT COALESCE(SUM(ram_go_machine), 0) INTO v_ram_utilisee
      FROM machine_virtuelle WHERE id_serveur = NEW.id_serveur;
    IF v_ram_utilisee + NEW.ram_go_machine > v_ram_serveur THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RAM insuffisante sur le serveur physique pour cette VM';
    END IF;
END//

CREATE TRIGGER trg_vm_bu BEFORE UPDATE ON machine_virtuelle
FOR EACH ROW
BEGIN
    DECLARE v_ram_serveur INT;
    DECLARE v_ram_utilisee INT;
    IF NEW.ram_go_machine <> OLD.ram_go_machine OR NEW.id_serveur <> OLD.id_serveur THEN
        SELECT ram_totale_go_serveur INTO v_ram_serveur
          FROM serveur_physique WHERE id_serveur = NEW.id_serveur;
        SELECT COALESCE(SUM(ram_go_machine), 0) INTO v_ram_utilisee
          FROM machine_virtuelle
         WHERE id_serveur = NEW.id_serveur AND id_machine <> OLD.id_machine;
        IF v_ram_utilisee + NEW.ram_go_machine > v_ram_serveur THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RAM insuffisante sur le serveur physique pour cette VM';
        END IF;
    END IF;
END//

DELIMITER ;
