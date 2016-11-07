////////////////////////////////////////////////////////////////////////////////
// Message Interfaces in Service Models subsystem, logic
// to be inherited from the SSL by the configurations applied in the service models.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Fills the transferred array with common modules which
//  comprise the handlers of received messages interfaces
//
// Parameters:
//  ArrayOfHandlers - array
//
Procedure FillReceivedMessageHandlers(ArrayOfHandlers) Export
	
	// Remote administration messages
	ArrayOfHandlers.Add(RemoteAdministrationMessagesInterface);
	// End Remote administration messages
	
	If CommonUseClientServer.SubsystemExists("StandardSubsystems.SaaS.DataAreasBackup") Then
		
		// Backup control messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("MessagesManageBackupInterface"));
		// End Backup control messages
		
	EndIf;
	
	If CommonUseClientServer.SubsystemExists("StandardSubsystems.SaaS.DataExchangeSaaS") Then
		
		// Data exchange administration control messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("MessagesDataExchangeAdministrationControlInterface"));
		// End Data exchange administration control messages
		
		// Data exchange administration control messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("MessagesDataExchangeAdministrationManagementInterface"));
		// End Data exchange administration control messages
		
		// Data exchange control messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("MessageControlDataExchangeInterface"));
		// End Data exchange control messages
		
		// Data exchange management messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("MessagesDataExchangeManagementInterface"));
		// End Data exchange management messages
		
	EndIf;
	
	If CommonUseClientServer.SubsystemExists("StandardSubsystems.InformationCenter") Then
		
		// Information center messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("InformationCenterMessagesInterface"));
		// End Information center messages
		
	EndIf;
	
EndProcedure

// Fills the transferred array with the common modules
//  being the sent message interface handlers
//
// Parameters:
//  ArrayOfHandlers - array
//
Procedure FillSendingMessageHandlers(ArrayOfHandlers) Export
	
	// Remote administration control messages
	ArrayOfHandlers.Add(MessageRemoteAdministratorControlInterface);
	// End Remote administration control messages
	
	// Aplication management messages
	ArrayOfHandlers.Add(MessagesManagementApplicationInterface);
	// End Aplication management messages
	
	If CommonUseClientServer.SubsystemExists("StandardSubsystems.SaaS.DataAreasBackup") Then
		
		// backup copying control messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("BackupControlMessageInterface"));
		// End Backup control messages
		
	EndIf;
	
	If CommonUseClientServer.SubsystemExists("StandardSubsystems.SaaS.DataExchangeSaaS") Then
		
		// Data exchange administration control messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("MessagesDataExchangeAdministrationControlInterface"));
		// End Data exchange administration control messages
		
		// Data exchange administration control messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("MessagesDataExchangeAdministrationManagementInterface"));
		// End Data exchange administration control messages
		
		// Data exchange control messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("MessageControlDataExchangeInterface"));
		// End Data exchange control messages
		
		// Data exchange management messages
		ArrayOfHandlers.Add(CommonUseClientServer.CommonModule("MessagesDataExchangeManagementInterface"));
		// End Data exchange management messages
		
	EndIf;
	
EndProcedure
