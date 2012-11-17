Scraper pour le rôle d'évaluation foncière de la Ville de Montréal: http://evalweb.ville.montreal.qc.ca/

For 2012, this represents $214,989,968,755.00 (215 *billion* dollars).

# Installation

    git clone ...
    
On Ubuntu, you may have to install some libraries first:

    sudo apt-get install rubygem libxslt1-dev
    gem install mechanize

# Usage

Start scraping:

    ./scrape-evalweb.rb
    tar czf evalweb-cache.tgz cache/address/

The scraper produces a `cache` directory, where it stores the web pages it fetched. This directory contains close to a million files, which is inefficient to store in a filesystem, but simple for lookup done by the scraper.

Once it is done, extract the data. This will create `evaluations.csv` as well as the SQL commands to load it into MySQL:

    ./export-evalweb.rb
    ./export-streets.rb

Let it finish (it can take hours for the tar archive generation, and an hour for the CSV export), then import the resulting files into MySQL:

    mysql -u root < evaluations.sql
    mysql -u root < streets.sql

You can now query the database:

    mysql -u root registre_foncier_montreal

# Downloads

You may spare yourself the scraping by downloading a cache from november 2012 with BitTorrent:

    magnet:?xt=urn:btih:cf07bef9dc9264abd8a0ab9c4412bea634065b1a&dn=evalweb-cache.tgz&tr=udp%3A%2F%2Ftracker.istole.it%3A80

Or download the CSV file directly:

    magnet:?xt=urn:btih:ef127f29e1d9fb5da12d93702bd77301b8e0bb83&dn=evaluations.csv&tr=udp%3A%2F%2Ftracker.istole.it%3A80

# Example Queries

## Total Value

    SELECT count(*),
        format(sum(valeur_terrain),0) as terrains,
        format(sum(valeur_batiment),0) as batiments,
        format(sum(valeur_immeuble),0) as immeubles
      FROM evaluations;

## Value by Borough

    SELECT ville, arrondissement, count(*),
        format(sum(valeur_terrain),0) as terrains,
        format(sum(valeur_batiment),0) as batiments,
        format(sum(valeur_immeuble),0) as immeubles
      FROM evaluations
      GROUP BY ville, arrondissement
      ORDER BY SUM(valeur_immeuble) DESC;

## Value by Owner

    SELECT proprietaire, count(*),
        format(sum(valeur_terrain),0) as terrains,
        format(sum(valeur_batiment),0) as batiments,
        format(sum(valeur_immeuble),0) as immeubles
      FROM evaluations
      GROUP BY proprietaire
      ORDER BY SUM(valeur_immeuble) DESC
      LIMIT 30;

## Value by Street

    SELECT
        substring(address_street.street_name, 1, LOCATE(',', address_street.street_name)-1) as street_name,
        count(*),
        format(sum(valeur_terrain),0) as terrains,
        format(sum(valeur_batiment),0) as batiments,
        format(sum(valeur_immeuble),0) as immeubles
      FROM evaluations
      JOIN address_street ON address_street.address_id = address.uef_id
      GROUP BY (street_name)
      ORDER BY SUM(valeur_immeuble) DESC
      LIMIT 30;

## Value of a Given Street, by Owner

    SELECT proprietaire, count(*),
        format(sum(valeur_terrain),0) as terrains,
        format(sum(valeur_batiment),0) as batiments,
        format(sum(valeur_immeuble),0) as immeubles
      FROM evaluations
      JOIN address_street ON address_street.address_id = address.uef_id
      WHERE substring(address_street.street_name, 1, LOCATE(',', address_street.street_name)-1)
        = 'SAINTE CATHERINE'
      GROUP BY (proprietaire)
      ORDER BY SUM(valeur_immeuble) DESC LIMIT 30;

## Most Expensive Lots on a Given Street

    SELECT proprietaire, adresse, address_id,
        format(valeur_terrain,0) as terrain,
        emplacement_superficie as superficice,
        format(valeur_terrain/emplacement_superficie,0) as valeur_terrain
      FROM evaluations
      JOIN address_street ON address_street.address_id = address.uef_id
      WHERE substring(address_street.street_name, 1, LOCATE(',', address_street.street_name)-1)
        = 'SAINTE CATHERINE'
      ORDER BY valeur_terrain/emplacement_superficie DESC
      LIMIT 30;

Now, get creative!

http://argent.canoe.ca/lca/financespersonnelles/quebec/archives/2010/01/20100111-113558.html
