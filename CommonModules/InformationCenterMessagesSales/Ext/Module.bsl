////////////////////////////////////////////////////////////////////////////////
// GENERAL IMPLEMENTATION OF INFO CENTER MESSAGES PROCESSOR
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

// Generates the "InfoCenterGeneralData" catalog item according to the message
//
// Parameters:
// MessageBody - XDTODataObject - message body.
//
Procedure AddNotificationOfWish(MessageBody) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		AddNotificationOfRequestToCatalog(MessageBody);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// Adds a notification if needed
//
// Parameters:
// MessageBody - XDTODataObject - message body.
//
Procedure AddNotificationOfRequestToCatalog(MessageBody)
	
	NotificationOfRequest                           = Catalogs.InformationCenterCommonData.CreateItem();
	NotificationOfRequest.ID             = MessageBody.id;
	NotificationOfRequest.Description              = MessageBody.name;
	NotificationOfRequest.ActualityBeginningDate    = MessageBody.startDate;
	NotificationOfRequest.ActualityEndingDate = MessageBody.endDate;
	NotificationOfRequest.InformationType             = InformationCenterServer.GetInformationTypeRef("NotificationOfRequest");
	NotificationOfRequest.Criticality               = MessageBody.criticality;
	NotificationOfRequest.Write();
	
EndProcedure





