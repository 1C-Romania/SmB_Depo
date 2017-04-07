#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTests") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SetFilter = Parameters.SetFilter;
	DataSeparationMatch = New Map;
	If SetFilter.Count() > 0 Then
		
		For Each SessionDelimiter IN SetFilter Do
			DataSeparationArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SessionDelimiter.Value, "=");
			DataSeparationMatch.Insert(DataSeparationArray[0], DataSeparationArray[1]);
		EndDo;
		
	EndIf;
	
	For Each CommonAttribute IN Metadata.CommonAttributes Do
		TableRow = SessionDataSeparation.Add();
		TableRow.Delimiter = CommonAttribute.Name;
		TableRow.SeparatorPresentation = CommonAttribute.Synonym;
		SeparatorValue = DataSeparationMatch[CommonAttribute.Name];
		If SeparatorValue <> Undefined Then
			TableRow.CheckBox = True;
			TableRow.SeparatorValue = DataSeparationMatch[CommonAttribute.Name];
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	Result = New ValueList;
	For Each TableRow IN SessionDataSeparation Do
		If TableRow.CheckBox Then
			SeparatorValue = TableRow.Delimiter + "=" + TableRow.SeparatorValue;
			SeparatorPresentation = TableRow.SeparatorPresentation + " = " + TableRow.SeparatorValue;
			Result.Add(SeparatorValue, SeparatorPresentation);
		EndIf;
	EndDo;
	
	Notify("EventLogMonitorFilterItemValueChoice",
		Result,
		FormOwner);
	
	Close();
EndProcedure

&AtClient
Procedure MarkAll(Command)
	For Each ItemOfList IN SessionDataSeparation Do
		ItemOfList.CheckBox = True;
	EndDo;
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	For Each ItemOfList IN SessionDataSeparation Do
		ItemOfList.CheckBox = False;
	EndDo;
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	Close();
EndProcedure

#EndRegion