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

      var data = result.rows[0].execution_queue_to_json;

      //scan array of tasks enqueued
      for (let i = 0; i < data.length; i++) {

        try {
        //  callEmailMessage(data[i]);
          updateQueueService(data[i].id);
        } catch (e) {
          //TODO: log problem
          sails.log.error(e.message);
          continue;
        }

      }

      return res.ok(data);

    });
  }
};

module.exports = ExecutionQueueServices;

//Private Functions
function callEmailMessage(data) {
  /*
      { id: 6,
          task_check_id: 18,
          next_execution: '2017-08-12T10:05:00',
          task_check_name: 'testes Funções DEV 2',
          task_check_description: 'Testes Funções Diário',
          place_name: 'Banheiro Feminino',
          name: 'Fernando Silva',
          email: 'fsilvapucci@gmail.com',
          mobile_message: '+553599915534',
          notifications: [ { notification_type_id: 19, notifications_type_name: 'e-mail' } ] }
  */

  var bodyMessage = data.name + "\n" +
    data.task_check_name + "\n" +
    data.place_name + "\n" +
    data.task_check_description + "\n";

  MessageServices.sendMailGun(data.email,
    "Nova tarefa para você!  [" + data.task_check_name + "].",
    bodyMessage,
    null);

  console.log(data);

};

function updateQueueService(id) {
  /*
  UPDATE EXECUTION_QUEUE
  SET EXECUTED = TRUE
  WHERE TASK_CHECK_ID=13;
  */
  TaskChecks.query("UPDATE EXECUTION_QUEUE SET EXECUTED = TRUE WHERE TASK_CHECK_ID = " + id, function (err, result) {
        
        if (err)
          throw new Exception(err);
        console.log(">>>>>>>>> " + id + "\n Updated");
        
      });
    }
    