app.controller("mailerController",["$scope", "$http", function ($scope, $http) {

	$scope.app = "GerPro API Page";

	$scope.sendMessage = function () {

		var mens = $scope.message;
	
		var send = {
						"to":$scope.message.to,
						"subject": $scope.message.subject,
						"message": $scope.message.msg
					};
	
		$http({
			url: 'api/message/sendMessage',
			method: 'POST',
			data: send,
			headers: {'Content-Type': 'application/json'}
		});

		$scope.message = [];
	};

}]);


