
#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	StructuresArray = New Array;
	
	Item = New Structure;
	Item.Insert("Object", "FileComparisonSettings");
	Item.Insert("Settings", "FileVersionComparisonMethod");
	Item.Insert("Value", FileVersionComparisonMethod);
	StructuresArray.Add(Item);
	
	CommonUseServerCall.CommonSettingsStorageSaveArrayAndUpdatereuseValues(
		StructuresArray);
	
	ChoiceResult = DialogReturnCode.OK;
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion
