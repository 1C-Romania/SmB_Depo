////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Info base update

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Handler of the update BED 1.1.3.7
// EDStatus attribute type modified in RS EDEventLogMonitor since a string on EnumRef.
Procedure UpdateEDStatuses() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDEventsLog.DeleteEDStatus,
	|	EDEventsLog.AttachedFile,
	|	EDEventsLog.RecNo
	|FROM
	|	InformationRegister.EDEventsLog AS EDEventsLog
	|WHERE
	|	EDEventsLog.DeleteEDStatus <> """"";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		RecordManager                    = InformationRegisters.EDEventsLog.CreateRecordManager();
		RecordManager.AttachedFile = Selection.AttachedFile;
		RecordManager.RecNo        = Selection.RecNo;
		RecordManager.Read();
		
		If Selection.DeleteEDStatus = "Delivered to recipient" Then
			DeleteEDStatus = Enums.EDStatuses.Delivered;
		ElsIf Selection.DeleteEDStatus = "<Not received>" Then
			DeleteEDStatus = Enums.EDStatuses.NotReceived;
		ElsIf Selection.DeleteEDStatus = "<Not formed>" Then
			DeleteEDStatus = Enums.EDStatuses.NotFormed;
		ElsIf Selection.DeleteEDStatus = "Sent to recipient" Then
			DeleteEDStatus = Enums.EDStatuses.Sent;
		ElsIf Selection.DeleteEDStatus = "Specification notification has been sent" Then
			DeleteEDStatus = Enums.EDStatuses.NotificationSent;
		ElsIf Selection.DeleteEDStatus = "Sent to the EDO operator" Then
			DeleteEDStatus = Enums.EDStatuses.TransferedToOperator;
		ElsIf Selection.DeleteEDStatus = "Notification on specification is received" Then
			DeleteEDStatus = Enums.EDStatuses.AnnouncementReceived;
		Else
			DeleteEDStatus = StrReplace(Selection.DeleteEDStatus, " ", "");
			DeleteEDStatus = Enums.EDStatuses[DeleteEDStatus];
		EndIf;
		
		RecordManager.EDStatus = DeleteEDStatus;
		
		InfobaseUpdate.WriteData(RecordManager);
	EndDo;
	
EndProcedure

#EndIf
