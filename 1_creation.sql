-- =============================================================================
-- 1_creation.sql — MPD du Cloud Provider (MySQL 8 / MariaDB 10.5+)
-- Mini-projet TI503N — Partie 2, étape III.B
--
-- Création des tables avec les contraintes d'intégrité :
--   * intégrité d'entité      : PRIMARY KEY, NOT NULL
--   * intégrité référentielle : FOREIGN KEY ... ON DELETE CASCADE ON UPDATE CASCADE
--
-- Toutes les associations du MCD ont une cardinalité 1,1 côté enfant : la clé
-- étrangère est donc NOT NULL et la seule action qui ne déclenche pas d'erreur
-- tout en respectant la cardinalité est CASCADE (SET NULL violerait le 1,1).
-- Les contraintes de validation (formats, domaines, règles métier) sont dans
-- 2_contraintes.sql.
-- =============================================================================

DROP DATABASE IF EXISTS cloud_provider;
CREATE DATABASE cloud_provider CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE cloud_provider;

-- -----------------------------------------------------------------------------
-- Partie commerciale : clients, abonnements, bases managées, tickets
-- -----------------------------------------------------------------------------

CREATE TABLE client (
    id_client       INT           NOT NULL,          -- 8 chiffres
    nom_entreprise  VARCHAR(100)  NOT NULL,
    mail_client     VARCHAR(150)  NOT NULL,
    num_tel_client  VARCHAR(15)   NOT NULL,
    CONSTRAINT pk_client PRIMARY KEY (id_client)
);

-- souscrire (client 1,n — abonnement 1,1)
CREATE TABLE abonnement (
    id_abonnement         BIGINT       NOT NULL,     -- 10 chiffres
    date_debut_abonnement DATE         NOT NULL,
    niveau_abonnement     VARCHAR(20)  NOT NULL,
    id_client             INT          NOT NULL,
    CONSTRAINT pk_abonnement PRIMARY KEY (id_abonnement),
    CONSTRAINT fk_abonnement_client FOREIGN KEY (id_client)
        REFERENCES client (id_client)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- inclure bd (abonnement 0,n — base de données 1,1)
CREATE TABLE base_de_donnees (
    id_base_de_donnees BIGINT       NOT NULL,        -- 12 chiffres
    nom_bd             VARCHAR(50)  NOT NULL,
    moteur_bd          VARCHAR(20)  NOT NULL,
    stockage_bd        INT          NOT NULL,        -- en Go, 6 chiffres
    id_abonnement      BIGINT       NOT NULL,
    CONSTRAINT pk_base_de_donnees PRIMARY KEY (id_base_de_donnees),
    CONSTRAINT fk_bd_abonnement FOREIGN KEY (id_abonnement)
        REFERENCES abonnement (id_abonnement)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ouvrir (client 0,n — ticket 1,1) et concerner (abonnement 0,n — ticket 1,1)
CREATE TABLE ticket_support (
    id_ticket                  BIGINT         NOT NULL,   -- 10 chiffres
    date_ouverture_ticket      DATETIME       NOT NULL,
    description                VARCHAR(2000)  NOT NULL,
    statut_ticket              VARCHAR(20)    NOT NULL,
    priorite_resolution_ticket VARCHAR(15)    NOT NULL,
    id_client                  INT            NOT NULL,
    id_abonnement              BIGINT         NOT NULL,
    CONSTRAINT pk_ticket_support PRIMARY KEY (id_ticket),
    CONSTRAINT fk_ticket_client FOREIGN KEY (id_client)
        REFERENCES client (id_client)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ticket_abonnement FOREIGN KEY (id_abonnement)
        REFERENCES abonnement (id_abonnement)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- -----------------------------------------------------------------------------
-- Partie infrastructure : centres de données, serveurs, machines virtuelles
-- -----------------------------------------------------------------------------

CREATE TABLE centre_de_donnees (
    id_centre          VARCHAR(10)  NOT NULL,        -- code, ex. FR-PAR-01
    ville_centre       VARCHAR(50)  NOT NULL,
    pays_centre        VARCHAR(50)  NOT NULL,
    capacite_mw_centre SMALLINT     NOT NULL,        -- en MW, 4 chiffres
    CONSTRAINT pk_centre_de_donnees PRIMARY KEY (id_centre)
);

-- heberger (centre 1,n — serveur 1,1)
CREATE TABLE serveur_physique (
    id_serveur            BIGINT       NOT NULL,     -- 12 chiffres
    ip_serveur            VARCHAR(15)  NOT NULL,
    ram_totale_go_serveur SMALLINT     NOT NULL,     -- en Go, 4 chiffres
    cpu_total_serveur     SMALLINT     NOT NULL,     -- 4 chiffres
    id_centre             VARCHAR(10)  NOT NULL,
    CONSTRAINT pk_serveur_physique PRIMARY KEY (id_serveur),
    CONSTRAINT fk_serveur_centre FOREIGN KEY (id_centre)
        REFERENCES centre_de_donnees (id_centre)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- allouer VM (abonnement 0,n — VM 1,1) et deployer (serveur 0,n — VM 1,1)
CREATE TABLE machine_virtuelle (
    id_machine          BIGINT       NOT NULL,       -- 12 chiffres
    os_machine          VARCHAR(30)  NOT NULL,
    ram_go_machine      SMALLINT     NOT NULL,       -- en Go, 4 chiffres
    vcpu_machine        SMALLINT     NOT NULL,       -- 3 chiffres
    hote_machine        VARCHAR(50)  NOT NULL,
    ip_publique_machine VARCHAR(15)  NULL,           -- une VM peut ne pas être exposée
    ip_privee_machine   VARCHAR(15)  NOT NULL,
    id_abonnement       BIGINT       NOT NULL,
    id_serveur          BIGINT       NOT NULL,
    CONSTRAINT pk_machine_virtuelle PRIMARY KEY (id_machine),
    CONSTRAINT fk_vm_abonnement FOREIGN KEY (id_abonnement)
        REFERENCES abonnement (id_abonnement)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_vm_serveur FOREIGN KEY (id_serveur)
        REFERENCES serveur_physique (id_serveur)
        ON DELETE CASCADE ON UPDATE CASCADE
);
