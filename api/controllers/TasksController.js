/**
 * TasksController
 *
 * @description :: Server-side logic for managing tasks
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */

module.exports = {
    //The REST operations is configured in policies.js
    //If you need create any new methor, enable this on policies.js
    
    //Same than 'find()'
    //Info: https://groups.google.com/forum/#!topic/sailsjs/vSQVHeKrGBo
    index: function (req, res) {
        TaskChecks.query("SELECT * FROM TASK_CHECKS", function (err, results) {
            if (err)
                return res.serverError(err);
            return res.ok(results.rows);
        });
    }

};

