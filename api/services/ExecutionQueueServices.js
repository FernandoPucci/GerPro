var bodyParser = require("body-parser");

var ExecutionQueueServices = {

  next: function nextQueueService(req, res) {
    ExecutionQueue.query("SELECT INSERT_INTO_EXECUTION_QUEUE()", function (err, result) {

      if (err) {
        //TODO: log error
        sails.log.error("[nextQueueService] " + err);
        return res.serverError(err);
      }

      return res.ok(result.rows);

    });

  },
  execute: function executeQueueService(req, res) {

    ExecutionQueue.query("SELECT EXECUTION_QUEUE_TO_JSON()", function (err, result) {
      if (err) {
        //TODO: log error
        sails.log.error("[executeQueueService] " + err);
        return res.serverError(err);
      }

      var data = result.rows[0].execution_queue_to_json;

      if (data) {
        //scan array of tasks enqueued
        for (let i = 0; i < data.length; i++) {

          try {
            callEmailMessage(data[i]); //TODO: call message method based in notification type id
            updateQueueService(data[i].id); //TODO: use promise 'then'
          } catch (e) {
            //TODO: log error
            sails.log.error("[executeQueueService] " + err);
            continue;
          }
        }

        return res.ok(data);

      }

      return res.ok([]);

    });
  }
};

module.exports = ExecutionQueueServices;

//Private Functions
function callEmailMessage(data) {

  var bodyMessage = data.name + "\n" +
    data.task_check_name + " [" + data.next_execution.toLocaleString() + "] \n" +
    data.place_name + "\n" +
    data.task_check_description + "\n";

  MessageServices.sendMailGun(data.email,
    "Nova tarefa para você!  [" + data.task_check_name + "].",
    bodyMessage,
    null);

  console.log(data);

}

function updateQueueService(idQueue) {

  ExecutionQueue.update({
    id: idQueue
  }, {
    executed: true
  }).exec(function afterwards(err, updated) {

    if (err) {
      throw new Exception(err);
    }

    console.log('Updated ' + updated.length + ' rows.');
    return;
  });

}
