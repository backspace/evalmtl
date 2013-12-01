# Fork note

I forked this because:

* it wasn’t working for the 2014 property assessments
* I was getting segfaults using DBM, maybe because I was running on MacOS?
* I needed only a subset of properties and a subset of fields from each property

My changes:

* added some diagnostic logging
* used Bundler for Ruby dependency management
* amended the evalweb caching to use the filesystem for `street` and `address`
* added a simple sqlite generator using DataMapper
* tweaked for parsing of 2014 assessment data

I see the project creator has a 2014 assessment fork which I didn’t realise until I was writing this!

## Usage

Assuming you have Ruby 1.9.3 and Bundler etc etc

    bundle install
    bundle exec ruby scrape-evalweb.rb
    
This process takes a long time as the script is systematically archiving every property assessment page. After it’s complete you can export a limited subset of the data to `export.db`:

    bundle exec ruby export-evalweb.rb
    
## Querying

Maybe I’ll add a web interface, but for now you can query the database using SQL directly, or using a minimalist DataMapper interface. Start off in IRB:

    irb
    require './lib/query'
   
Say we want to find the properties owner by notorious capitalist Peter Sergakis.

    Owner.all.select{|o| o.name.include? "SERGA"}
   
My database contained two Owner records. I can list the units owned by an owner like this:

    Owner.get(3677).units
    
## Fork note over
    
Below is the existing documentation. Some of it no longer applies.

# Original documentation

Scraper pour le rôle d'évaluation foncière de la Ville de Montréal: http://evalweb.ville.montreal.qc.ca/

For 2012, this represents $214,989,968,755.00 (215 *billion* dollars).

# Installation

    git clone ...
    
On Ubuntu, you may have to install some libraries first:

    sudo apt-get install rubygems libxslt1-dev
    gem install mechanize
    gem install minitar

# Usage

Start scraping:

    ./scrape-evalweb.rb

The scraper produces dir and pag files, where it stores the web pages it fetched.

Once it is done, extract the data. This will create `evaluations.csv` as well as the SQL commands to load it into MySQL:

    ./export-evalweb.rb
    ./export-streets.rb

Let it finish (it can take hours for the tar archive generation, and an hour for the CSV export), then import the resulting files into MySQL:

    mysql --local-infile -u root < evaluations.sql
    mysql --local-infile -u root < streets.sql

You can now query the database:

    mysql -u root evalmtl

# Downloads

You may spare yourself the scraping by downloading a cache from november 2012 with BitTorrent:

    magnet:?xt=urn:btih:cf07bef9dc9264abd8a0ab9c4412bea634065b1a&dn=evalweb-cache.tgz&tr=udp%3A%2F%2Ftracker.istole.it%3A80

Or download the CSV file directly:

    magnet:?xt=urn:btih:5fdd555ff92acb6fb300a50c71d90516770aeda3&dn=evaluations.csv.gz&tr=udp%3A%2F%2Ftracker.istole.it%3A80

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
      JOIN address_street ON address_street.address_id = evaluations.uef_id
      GROUP BY (street_name)
      ORDER BY SUM(valeur_immeuble) DESC
      LIMIT 30;

## Value of a Given Street, by Owner

    SELECT proprietaire, count(*),
        format(sum(valeur_terrain),0) as terrains,
        format(sum(valeur_batiment),0) as batiments,
        format(sum(valeur_immeuble),0) as immeubles
      FROM evaluations
      JOIN address_street ON address_street.address_id = evaluations.uef_id
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
      JOIN address_street ON address_street.address_id = evaluations.uef_id
      WHERE substring(address_street.street_name, 1, LOCATE(',', address_street.street_name)-1)
        = 'SAINTE CATHERINE'
      ORDER BY valeur_terrain/emplacement_superficie DESC
      LIMIT 30;

## Land Value Average by Street

    SELECT
        address_street.street_name,
        count(*) as nb_terrains,
        sum(valeur_terrain) as valeur_total_terrains,
        sum(emplacement_superficie) as total_superficie,
        sum(valeur_terrain) / sum(emplacement_superficie) as valeur_moyenne
      FROM evaluations
      JOIN address_street ON address_street.address_id = evaluations.uef_id
      GROUP BY (street_name)
      ORDER BY street_name ASC
      LIMIT 100;

# Merge Street Name with Lot

For big queries, joining on the address_street table can be expensive, so it is a good idea to merge the two together. However, some lots have multiple addresses, so let's keep in mind we'll be picking just one per lot.

    ALTER TABLE evaluations ADD COLUMN street_name varchar(200);
    UPDATE evaluations
      JOIN address_street on address_street.address_id = evaluations.uef_id
      SET evaluations.street_name = address_street.street_name;
    CREATE INDEX evaluations_street_name_index ON evaluations (street_name);

## Land Value Average by Street

    SELECT
        street_name,
        count(*) as nb_terrains,
        sum(valeur_terrain) as valeur_total_terrains,
        sum(emplacement_superficie) as total_superficie,
        sum(valeur_terrain) / sum(emplacement_superficie) as valeur_moyenne
      FROM evaluations
      GROUP BY (street_name)
      ORDER BY street_name ASC
      LIMIT 100;

## Land Difference with Street Average

    SELECT
        proprietaire,
        adresse,
        no_lot_renove,
        nb_etages,
        valeur_terrain,
        emplacement_superficie as superficie,
        street_average.valeur_moyenne,
        valeur_terrain / emplacement_superficie as valeur,
        valeur_terrain / emplacement_superficie - street_average.valeur_moyenne as difference,
        street_average.valeur_moyenne * emplacement_superficie - valeur_terrain as manque
      FROM evaluations
      JOIN (
        SELECT
            street_name,
            sum(valeur_terrain) / sum(emplacement_superficie) as valeur_moyenne
          FROM evaluations
          WHERE emplacement_superficie > 50
          GROUP BY street_name
      ) AS street_average ON street_average.street_name = evaluations.street_name
      WHERE valeur_terrain / emplacement_superficie - street_average.valeur_moyenne < 50
      ORDER BY manque DESC
      LIMIT 100;

Now, get creative!

http://argent.canoe.ca/lca/financespersonnelles/quebec/archives/2010/01/20100111-113558.html

