/**
 * MytasksController
 *
 * @description :: Server-side logic for managing mytasks
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */

module.exports = {
	index: function (req, res) {
        user_checker_id = req.param('user_checker_id');
        if(user_checker_id == undefined) user_checker_id = null;
        TaskChecks.query("SELECT json_array_elements(next_executions_as_json(" + user_checker_id + ")) AS task_check;", function (err, results) {
            if (err)
                return res.serverError(err);
            return res.ok(results.rows);
        });
    }
};

