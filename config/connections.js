/**
 * Connections
 * (sails.config.connections)
 *
 * `Connections` are like "saved settings" for your adapters.  What's the difference between
 * a connection and an adapter, you might ask?  An adapter (e.g. `sails-mysql`) is generic--
 * it needs some additional information to work (e.g. your database host, password, user, etc.)
 * A `connection` is that additional information.
 *
 * Each model must have a `connection` property (a string) which is references the name of one
 * of these connections.  If it doesn't, the default `connection` configured in `config/models.js`
 * will be applied.  Of course, a connection can (and usually is) shared by multiple models.
 * .
 * Note: If you're using version control, you should put your passwords/api keys
 * in `config/local.js`, environment variables, or use another strategy.
 * (this is to prevent you inadvertently sensitive credentials up to your repository.)
 *
 * For more information on configuration, check out:
 * http://sailsjs.org/#!/documentation/reference/sails.config/sails.config.connections.html
 */

module.exports.connections = {

  /***************************************************************************
  *                                                                          *
  * Local disk storage for DEVELOPMENT ONLY                                  *
  *                                                                          *
  * Installed by default.                                                    *
  *                                                                          *
  ***************************************************************************/
  // localDiskDb: {
  //   adapter: 'sails-disk'
  // },

  /***************************************************************************
  *                                                                          *
  * PostgreSQL is another officially supported relational database.          *
  * http://en.wikipedia.org/wiki/PostgreSQL                                  *
  *                                                                          *
  * Run: npm install sails-postgresql                                        *
  *                                                                          *
  *                                                                          *
  ***************************************************************************/
  //DEV
  // dbServerDEV: {
  //   adapter: 'sails-postgresql',
  //   host: 'win_server',
  //   user: 'postgres', // optional
  //   password: '123456', // optional
  //   database: 'GERPRO_DEV' //optional
  // },
  dbServerDEV: {
    adapter: 'sails-postgresql',
    host: 'localhost',
    user: 'postgres', // optional
    password: '123456', // optional
    database: 'gerpro_dev' //optional
  },

  //HEROKU-DEV
  dbServerPRD: {
    adapter: 'sails-postgresql',
    host: process.env.DB_HOST_PRD,
    user: process.env.DB_USER_PRD, // optional
    password: process.env.DB_PASSWORD_PRD, // optional
    database: process.env.DB_DATABASE_PRD, //optional
    ssl      : true
  }


  /***************************************************************************
  *                                                                          *
  * More adapters: https://github.com/balderdashy/sails                      *
  *                                                                          *
  ***************************************************************************/

};
