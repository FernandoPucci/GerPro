/**
 * MytasksController
 *
 * @description :: Server-side logic for managing mytasks
 * @help        :: See http://sailsjs.org/#!/documentation/concepts/Controllers
 */

module.exports = {
	index: function (req, res) {
        TaskChecks.query("SELECT json_array_elements(next_executions_as_json(2)) AS task_check;", function (err, results) {
            if (err)
                return res.serverError(err);
            return res.ok(results.rows);
        });
    }
};

