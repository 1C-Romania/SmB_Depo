////////////////////////////////////////////////////////////////////////////////
// MESSAGE CHANNEL HANDLER FOR VERSION
//  1.0.3.1 DATA AREA BACKUP MANAGEMENT MESSAGE INTERFACE
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns version name space of message interface.
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ManageZonesBackup/" + Version();
	
EndFunction

// Returns message interface version, served by the handler.
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns default type for version messages.
Function BaseType() Export
	
	Return MessagesSaaSReUse.TypeBody();
	
EndFunction

// Processes incoming messages in service model.
//
// Parameters:
//  Message - ObjectXDTO, incoming message, 
//  Sender - ExchangePlanRef.MessageExchange, exchange node plan corresponding to the message sender.
//  MessageHandled - Boolean, a flag showing that the message is successfully processed. The value of this parameter shall be set to True
//  if the message was successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageHandled) Export
	
	MessageHandled = True;
	
	Dictionary = MessagesManageBackupInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessagePlanZoneBackup(Package()) Then
		PlanAreaArchiving(Message, Sender);
	ElsIf MessageType = Dictionary.MessageRefreshSettingsPeriodicBackup(Package()) Then
		RefreshSettingsPeriodicBackup(Message, Sender);
	ElsIf MessageType = Dictionary.MessageCancelPeriodicBackup(Package()) Then
		CancelRecurringBackupCopy(Message, Sender);
	Else
		MessageHandled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure PlanAreaArchiving(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesControlBackupCopyImplementation.PlanAreaBackupCreating(
		MessageBody.Zone,
		MessageBody.BackupId,
		MessageBody.Date,
		True);
	
EndProcedure

Procedure RefreshSettingsPeriodicBackup(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	
	Settings = New Structure;
	Settings.Insert("CreateDaily", MessageBody.CreateDailyBackup);
	Settings.Insert("CreateMonthly", MessageBody.CreateMonthlyBackup);
	Settings.Insert("CreateAnnual", MessageBody.CreateYearlyBackup);
	Settings.Insert("OnlyWhenActiveUsers", MessageBody.CreateBackupOnlyAfterUsersActivity);
	Settings.Insert("BeginOfIntervalOfCopiesFormation", MessageBody.BackupCreationBeginTime);
	Settings.Insert("EndOfIntervalFormationCopies", MessageBody.BackupCreationEndTime);
	Settings.Insert("DayOfMonth", MessageBody.MonthlyBackupCreationDay);
	Settings.Insert("MonthOfCreationAnnual", MessageBody.YearlyBackupCreationMonth);
	Settings.Insert("DayOfAnnual", MessageBody.YearlyBackupCreationDay);
	Settings.Insert("CreationDateOfLastDaily", MessageBody.LastDailyBackupDate);
	Settings.Insert("CreationDateOfLastMonthly", MessageBody.LastMonthlyBackupDate);
	Settings.Insert("CreationDateOfLastAnnual", MessageBody.LastYearlyBackupDate);
	
	MessagesControlBackupCopyImplementation.RefreshSettingsPeriodicBackup(
		MessageBody.Zone,
		Settings);
	
EndProcedure

Procedure CancelRecurringBackupCopy(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	
	MessagesControlBackupCopyImplementation.CancelRecurringBackupCopy(
		MessageBody.Zone);
	
EndProcedure

#EndRegion
