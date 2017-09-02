/**
 * ParametersController
 *
 * @description :: Server-side logic for managing Parameters
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 * 
 * To Select Parameters by CATEGORY_NAME: 
 * /api/parameters?category_name=<cat_name>
 * 
 * To Get all available categories:
 * /api/parameters/categories
 * 
 * 
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

