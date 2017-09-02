/**
 * CompaniesController
 *
 * @description :: Server-side logic for managing companies
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */

module.exports = {
  //The REST operations is configured in policies.js
  //If you need create any new method, enable this on policies.js

  places: function (req, res) {

    if (req.param('company_id')) {
      Companies.query("SELECT P.ID " +
        " , P.COMPANY_ID " +
        " , P.NAME " +
        " , P.DESCRIPTION " +
        " FROM PLACES P " +
        " JOIN COMPANIES C ON C.ID = P.COMPANY_ID " +
        " AND C.ID = '" + req.param('company_id') + "'",
        function (err, results) {
          if (err)
            return res.serverError(err);
          return res.ok(results.rows);
        });
    } else return res.serverError("Parameter 'company_id' can't be null. \n Try Call: \n '/api/companies/places?company_id=some_valid_company_id' ");
  },

  users: function (req, res) {

    if (req.param('company_id')) {
      Companies.query("SELECT  U.ID " +
        " , U.COMPANY_ID " +
        " , U.USER_NAME " +
        " , U.NAME " +
        " , U.EMAIL " +
        " , U.MOBILE_MESSAGE " +
        " FROM USERS U  " +
        " JOIN COMPANIES C ON C.ID = U.COMPANY_ID " +
        " AND C.ID  = '" + req.param('company_id') + "'",
        function (err, results) {
          if (err)
            return res.serverError(err);
          return res.ok(results.rows);
        });
    } else return res.serverError("Parameter 'company_id' can't be null. \n Try Call: \n '/api/companies/users?company_id=some_valid_company_id' ");
  }


};
