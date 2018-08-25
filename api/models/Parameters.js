/**
 * Parameters.js
 *
 * @description :: Representative model from Parameters table
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {

//connection: 'db_server',
  //configurations to disable UpdateAt and CreatedAt Waterline Columns
  tableName: 'parameters',
  autoCreatedAt: false,
  autoUpdatedAt: false,
  attributes: {

    id: {
      type: 'integer',
      autoIncrement: true,
      unique: true,
      primaryKey: true
    },  
    category_name: {
      type: 'string',
      required: true
    },
    key_name: {
      type: 'string',
      required: true
    },
    key_type: {
      type: 'string',
      required: true
    },
    key_value: {
      type: 'string',
      required: true
    },
    created_at: {
      type: 'datetime'
    },
    updated_at: {
      type: 'datetime'
    },
    updated_by_user: {
      type: 'integer',
      columnName: 'updated_by_user_id',
      required: true
    },
    
    taskCheckResults: {
      collection: 'taskCheckResults',
      via: 'result_id'
    }
  }  
};

