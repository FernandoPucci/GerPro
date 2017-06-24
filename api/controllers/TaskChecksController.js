/**
 * TaskChecksController
 *
 * @description :: Server-side logic for managing Taskchecks
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */

module.exports = {

    createTask: function(req, res){
        
        TaskChecksServices.save(req, res);        

    }

};

