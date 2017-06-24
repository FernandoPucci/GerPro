var bodyParser = require("body-parser");

var TaskChecksServices = {

    save: function saveService(json, res) {

        //#### DEBUG
        // console.log(json.body.description);
        // console.log(json.body.notifications);
        // console.log("\n\n*************************************\n\n")
        // console.log(json.body);
        

        TaskChecks.query("SELECT INSERT_TASKCHECKJSON('" + JSON.stringify(json.body) + "')", function (err, results) {
            if (err)
                return res.serverError(err);
            return res.created(results.rows);
        });
    }
};

module.exports = TaskChecksServices; 