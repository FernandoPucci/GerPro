var cron = require('node-cron');

////////// UTILS
var logFunction = function log() {
  return "Function fired at: >>> " + new Date().toLocaleString();
};

var messageTestFunction = function (req, res) {

  MessageServices.sendMailGun("fsilvapucci@gmail.com",
    "Cron Message = " + new Date().toLocaleString(),
    "This is an automatic Cron Message = " + new Date().toLocaleString(),
    res);
};


var lastExecution = "N/A";

var task = null;

//USAGE ONLY IN DEVELOPMENT
//FOR FUTURE SPRINTS, EXPRESSION WILL SEND IN POST, ON START

/// Node-Cron Instructions
/**
 * 
 # ┌────────────── second (optional)
 # │ ┌──────────── minute
 # │ │ ┌────────── hour
 # │ │ │ ┌──────── day of month
 # │ │ │ │ ┌────── month
 # │ │ │ │ │ ┌──── day of week
 # │ │ │ │ │ │
 # │ │ │ │ │ │
 # * * * * * *

 Example:

 Every second divisible by 10 (ended with 0)
 "* /10 * * * * *"
 */
var cronExpression = '0 */5 * * * *'; //5 minutes refreshing
//var cronExpression = '*/5 * * * * *';//5 seconds refreshing

var CronServices = {

  startCron: function fcnStartCron() {

    if (!task) {
      sails.log("Starting CRON feature");

      try {
        task = cron.schedule(cronExpression, function () {
          console.log(logFunction());

          //CALLING KEEP-ALIVE REQUEST
          KeepAliveServices.keep_alive();

          //messageTestFunction();

          //CALLING FUNCTION TO ENQUEUE NEXT TASKS
          KeepAliveServices.nextQueue();

          //CALLING FUNCTION TO EXECUTE QUEUED TASKS
          KeepAliveServices.executeQueue();
          lastExecution = new Date().toLocaleString();

        });

        task.start();

      } catch (err) {
        sails.log.error("Function START ERROR: " + err);
        return ("Function START ERROR: " + err);
      }

      sails.log("DONE");
    } else {
      sails.log("START:\n You have a TASK running and can't start another! Please call STOP before\n" +
        "Configuration: " + cronExpression +
        "\nLast Execution at: " + lastExecution);

      return "START:\n You have a TASK running and can't start another! Please call STOP before\n" +
        "Configuration: " + cronExpression +
        "\nLast Execution at: " + lastExecution;
    }
    return 200;

  },

  stopCron: function fcnStopCron() {

    sails.log("Stopping CRON feature");

    try {
      if (task !== null) {

        task.stop();
        task = null;

      } else {
        sails.log.error("There's NOT any TASK running!");
        return ("There's NOT any TASK running!");
      }

    } catch (err) {
      sails.log.error("Function STOP ERROR: " + err);
      return ("Function STOP ERROR: " + err);
    }

    sails.log("DONE");
    return 200;
  },

  checkCron: function fcnCheckCron() {

    sails.log("Checking CRON status");

    if (task !== null) {
      sails.log("HEALTHCHECK:\nTASK running!\n" +
        "Configuration: " + cronExpression +
        "\nLast Execution at: " + lastExecution);

      return ("HEALTHCHECK:\nTASK running!\n" +
        "Configuration: " + cronExpression +
        "\nLast Execution at: " + lastExecution);
    } else {
      sails.log("HEALTHCHECK:\nThere's NOT any TASK running!");
      return ("HEALTHCHECK:\nThere's NOT any TASK running!" + "\n" +
        sails.config.environment_config.teste);
    }
  }
};

module.exports = CronServices;
