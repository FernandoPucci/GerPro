/**
 * ParametersController
 *
 * @description :: Server-side logic for managing Parameters
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */

module.exports = {
    
    categories: function(req, res){
        
        Parameters.query("SELECT DISTINCT(CATEGORY_NAME) FROM PARAMETERS", function (err, results) {
            if (err)
                return res.serverError(err);
            return res.ok(results.rows);
        });      

    }

};

