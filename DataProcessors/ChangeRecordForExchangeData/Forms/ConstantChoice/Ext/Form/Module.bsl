
#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ConstantList.Clear();
	For CurInd = 0 To Parameters.ArrayOfMetadataNames.UBound() Do
		String = ConstantList.Add();
		String.PictureIndexAutoRecord = Parameters.ArrayAutoRecord[CurInd];
		String.PictureIndex                = 2;
		String.MetaFullName                 = Parameters.ArrayOfMetadataNames[CurInd];
		String.Description                  = Parameters.PresentationArray[CurInd];
	EndDo;
	
	TitleAutoRecord = NStr("en = 'Autoregistration for node ""%1""'");
	
	Items.DecorationAutoRecord.Title = StrReplace(TitleAutoRecord, "%1", Parameters.ExchangeNode);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CurParameters = SetFormParameters();
	Items.ConstantList.CurrentRow = CurParameters.CurrentRow;
EndProcedure

&AtClient
Procedure OnReopen()
	CurParameters = SetFormParameters();
	Items.ConstantList.CurrentRow = CurParameters.CurrentRow;
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersConstantList
//

&AtClient
Procedure ConstantListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	MakeCaseConstants();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers
//

// Performs constant selection
//
&AtClient
Procedure ChooseConstant(Command)
	
	MakeCaseConstants();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
//

// Performs selection and notifies about it.
//
&AtClient
Procedure MakeCaseConstants()
	Data = New Array;
	For Each CurrentStringItem IN Items.ConstantList.SelectedRows Do
		CurRow = ConstantList.FindByID(CurrentStringItem);
		Data.Add(CurRow.MetaFullName);
	EndDo;
	NotifyChoice(Data);
EndProcedure	

&AtServer
Function SetFormParameters()
	Result = New Structure("CurrentRow");
	If Parameters.ChoiceInitialValue <> Undefined Then
		Result.CurrentRow = RowIDMetaName(Parameters.ChoiceInitialValue);
	EndIf;
	Return Result;
EndFunction

&AtServer
Function RowIDMetaName(FullMetadataName)
	Data = FormAttributeToValue("ConstantList");
	CurRow = Data.Find(FullMetadataName, "MetaFullName");
	If CurRow <> Undefined Then
		Return CurRow.GetID();
	EndIf;
	Return Undefined;
EndFunction

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
