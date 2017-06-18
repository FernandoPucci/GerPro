/**
 * Users.js
 *
 * @description :: Representative model from Users table
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {
  //connection: 'db_server',
  //configurations to disale UpdateAt and CreatedAt Waterline Columns
  autoCreatedAt: false,
  autoUpdatedAt: false,
  attributes: {

    id: {
      type: 'integer',
      autoIncrement: true,
      unique: true,
      primaryKey: true
    },
    user_name: {
      type: 'string',
      required: true
    },
    password: {
      type: 'string',
      required: true
    },
    name: {
      type: 'string',
      required: true
    },
    email: {
      type: 'string',
    },
    mobile_message: {
      type: 'string',
    },
    cpf: {
      type: 'string',
      required: true
    },
    administrator: {
      type: 'boolean',
      required: true
    },
    company_id: {
      type: 'integer',
      required: true
    },
    created_at: {
      type: 'datetime',
      required: true
    },
    updated_at: {
      type: 'datetime',
      required: true
    },
    updated_by_user: {
      type: 'integer',
      columnName: 'updated_by_user_id'
    }
  }
};

