app.controller("mailerController",["$scope", "$http", function ($scope, $http) {

	$scope.app = "GerPro Mailer Test";

	$scope.sendMessage = function () {

		var mens = $scope.message;
	
		var send = {
						"to":$scope.message.to,
						"subject": $scope.message.subject,
						"message": $scope.message.msg
					};
	
		$http({
			url: 'message/sendMessage',
			method: 'POST',
			data: send,
			headers: {'Content-Type': 'application/json'}
		});

		$scope.message = [];
	};

}]);


