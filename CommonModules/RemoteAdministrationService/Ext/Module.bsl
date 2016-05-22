////////////////////////////////////////////////////////////////////////////////
// The Deleted administration subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.SaaS\OnSetInfobaseParameterValues"].Add(
		"RemoteAdministrationService");
	
	ServerHandlers["StandardSubsystems.SaaS.MessageExchange\RegistrationOfReceivedMessageInterfaces"].Add(
		"RemoteAdministrationService");
	
	ServerHandlers["StandardSubsystems.SaaS.MessageExchange\RegistrationSendingMessageInterfaces"].Add(
		"RemoteAdministrationService");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Called before attempting to write IB parameter values
// to the constants with the same name.
//
// Parameters:
// ParameterValues - Structure - values of parameters to be set.
// If the parameter value is set to this procedure, it
// is required to delete the corresponding pair KeyAndValue from the structure.
//
Procedure OnSetInfobaseParameterValues(Val ParameterValues) Export
	
	If ParameterValues.Property("ServiceURL") Then
		Constants.InternalServiceManagerURL.Set(ParameterValues.ServiceURL);
		ParameterValues.Delete("ServiceURL");
	EndIf;
	
	If ParameterValues.Property("AuxiliaryServiceUserName") Then
		Constants.ServiceManagerOfficeUserName.Set(ParameterValues.AuxiliaryServiceUserName);
		ParameterValues.Delete("AuxiliaryServiceUserName");
	EndIf;
	
	If ParameterValues.Property("AuxiliaryServiceUserPassword") Then
		Constants.ServiceManagerOfficeUserPassword.Set(ParameterValues.AuxiliaryServiceUserPassword);
		ParameterValues.Delete("AuxiliaryServiceUserPassword");
	EndIf;
	
EndProcedure

// Fills the transferred array with common modules which
//  are the handlers of the received messages interfaces.
//
// Parameters:
//  ArrayOfHandlers - array.
//
Procedure RegistrationOfReceivedMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(RemoteAdministrationMessagesInterface);
	
EndProcedure

// Fills the transferred array with common modules which
//  are the interface handlers of messages being sent.
//
// Parameters:
//  ArrayOfHandlers - array.
//
//
Procedure RegistrationSendingMessageInterfaces(ArrayOfHandlers) Export
	
	ArrayOfHandlers.Add(MessageRemoteAdministratorControlInterface);
	ArrayOfHandlers.Add(MessagesManagementApplicationInterface);
	
EndProcedure

#EndRegion
