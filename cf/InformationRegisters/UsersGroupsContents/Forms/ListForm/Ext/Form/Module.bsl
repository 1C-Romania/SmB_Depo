
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EnableEditingAbility(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure RefreshDataRegister(Command)
	
	HasChanges = False;
	
	RegisterDataUpdateOnServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en='Updated successfully.';ru='Обновление выполнено успешно.'");
	Else
		Text = NStr("en='No need to update.';ru='Обновление не требуется.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure RegisterDataUpdateOnServer(HasChanges)
	
	InformationRegisters.UsersGroupsContents.RefreshDataRegister(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion














