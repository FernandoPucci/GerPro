var bodyParser = require("body-parser");

var ExecutionQueueServices = {

    execute: function executeQueueService(req, res) {

        //#### DEBUG
        // console.log(json.body.description);
        // console.log(json.body.notifications);
        // console.log("\n\n*************************************\n\n")
        // console.log(json.body);

    TaskChecks.query("SELECT EXECUTION_QUEUE_TO_JSON()", function (err, result) {
            if (err)
                return res.serverError(err);  

            return res.ok(result.rows[0].execution_queue_to_json);
        });
    }, 

    update: function updateQueueService(id, res){

        console.log(id);

    }
};

module.exports = ExecutionQueueServices; 