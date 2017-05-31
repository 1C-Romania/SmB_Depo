&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("CurrentStatus",DocumentStatus);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateDialog();
	
EndProcedure

&AtClient
Procedure ApplySettings(Command)
	
	If NOT CheckFilling() Then
		Return;
	EndIf;	
	
	ParametersStructure = New Structure("Status, Comment",DocumentStatus, Comment);
	PutToTempStorage(ParametersStructure,Parameters.TempStorageAddress);
	
	NotifyChoice(True);
	
EndProcedure

&AtClient
Procedure DocumentStatusOnChange(Item)
	
	If DocumentStatus <> PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed") Then
		Comment = "";
	EndIf;
	
	UpdateDialog();

EndProcedure


&AtClient
Procedure UpdateDialog()
	
	Items.Comment.Enabled = (DocumentStatus = PredefinedValue("Enum.DocumentBookkeepingStatus.BookkeepingPostingIsNotAllowed"));
	
EndProcedure

