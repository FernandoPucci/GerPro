/**
 * Policy Mappings
 * (sails.config.policies)
 *
 * Policies are simple functions which run **before** your controllers.
 * You can apply one or more policies to a given controller, or protect
 * its actions individually.
 *
 * Any policy file (e.g. `api/policies/authenticated.js`) can be accessed
 * below by its filename, minus the extension, (e.g. "authenticated")
 *
 * For more information on how policies work, see:
 * http://sailsjs.org/#!/documentation/concepts/Policies
 *
 * For more information on configuring policies, check out:
 * http://sailsjs.org/#!/documentation/reference/sails.config/sails.config.policies.html
 */


module.exports.policies = {

  /***************************************************************************
  *                                                                          *
  * Default policy for all controllers and actions (`true` allows public     *
  * access)                                                                  *
  *                                                                          *
  ***************************************************************************/



  //Enable Rest operations fom AuditionsController
  AuditionsController: {
    'find': true,
    'findOne': true,
    '*': false
  },
  //Enable Rest operations fom CompaniesController
  CompaniesController: {
    'create': true,
    'findOne': true,
    'find': true,
    'update': true, //PUT
    '*': false
  },
  //Enable Rest operations fom MessageController
  MessageController: {
    'sendMessage': true,
    'callMessages': true,
    'findOne': true,
    '*': false
  },
  //Enable Rest operations fom PlacesController
  PlacesController: {
    'create': true,
    'findOne': true,
    'find': true,
    'update': true, //PUT
    '*': false
  },

  //Enable Rest operations fom TasksController
  TasksController: {
    'index': true,
    '*': false
  },
  //Enable Rest operations fom UsersController
  UsersController: {
    'create': true,
    'findOne': true,
    'find': true,
    'update': true, //PUT
    '*': false
  },

  //////////////////ONLY FOR TESTS PURPOSES//////////////////
  TaskChecksController: {
    'createTask':true,
    'create': true,
    'findOne': true,
    'find': true,
    'update': true, //PUT
    'populate': true,
    '*': false
  },
  DaysTimesController: {
    // 'create': true,
    // 'findOne': true,
    // 'find': true,
    // 'update': true, //PUT
    '*': false
  },
  NotificationsController: {
    'create': true,
    'findOne': true,
    'find': true,
    'update': true, //PUT
    '*': false
  },
  WeeksDaysController: {
    // 'create': true,
    // 'findOne': true,
    // 'find': true,
    // 'update': true, //PUT
    '*': false
  },
  ExecutionQueueController: {    
    'findOne': true,
    'find': true,
    //'update': true, //PUT
    '*': false
  },
  //////////////////////////////////////////////////////////
  // '*': true,

  /***************************************************************************
  *                                                                          *
  * Here's an example of mapping some policies to run before a controller    *
  * and its actions                                                          *
  *                                                                          *
  ***************************************************************************/
  // RabbitController: {

  // Apply the `false` policy as the default for all of RabbitController's actions
  // (`false` prevents all access, which ensures that nothing bad happens to our rabbits)
  // '*': false,

  // For the action `nurture`, apply the 'isRabbitMother' policy
  // (this overrides `false` above)
  // nurture	: 'isRabbitMother',

  // Apply the `isNiceToAnimals` AND `hasRabbitFood` policies
  // before letting any users feed our rabbits
  // feed : ['isNiceToAnimals', 'hasRabbitFood']
  // }
};
