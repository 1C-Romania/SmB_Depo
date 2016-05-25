
#Region ServiceProceduresAndFunctions

&AtClient
Function FieldAlreadySpecifiedInAnotherColumn(Field)
	
	Return (Field.ColumnNumber <> 0);
	
EndFunction

&AtServer
Procedure AddFields(FieldsParent, FieldsGroup, ColorNumber, IsCustomFieldsGroup = False)
	
	For Each Field IN FieldsGroup.Rows Do
		
		If Field.Visible Then
			
			NewRow 						= FieldsParent.Rows.Add();
			NewRow.FieldsGroupName			= Field.FieldsGroupName;
			NewRow.DerivedValueType	= Field.DerivedValueType;
			NewRow.FieldName					= Field.FieldName;
			NewRow.FieldPresentation		= Field.FieldPresentation;
			NewRow.ColumnNumber			= Field.ColumnNumber;
			
			If NewRow.ColumnNumber <> 0 Then
				
				NewRow.ColorNumber			= 3;
				If IsCustomFieldsGroup Then
					
					FieldsParent.ColorNumber	= 3;
					
				EndIf;
				
			Else
				
				NewRow.ColorNumber			= ?(Field.RequiredFilling, 1, ColorNumber);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillImportFieldsTree(FillingObjectFullName)
	Var GroupsAndFields;
	
	FieldsTree = FormAttributeToValue("ImportFieldsTree", Type("ValueTree"));
	DataImportFromExternalSources.CreateAndFillGroupAndFieldsByObjectNameTree(FillingObjectFullName, GroupsAndFields);
	DataImportFromExternalSources.FillColumnNumbersInMandatoryFieldsAndGroupsTree(GroupsAndFields, SpreadsheetDocument);
	
	NewRow = FieldsTree.Rows.Add();
	NewRow.FieldPresentation	= "Not to import";
	
	For Each FieldsGroup IN GroupsAndFields.Rows Do
		
		If FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsGroupNameService() Then
			
			Continue;
			
		EndIf;
		
		ColorNumber						= 0;
		IsCustomFieldsGroup	= DataImportFromExternalSources.IsCustomFieldsGroup(FieldsGroup.FieldsGroupName);
		If IsCustomFieldsGroup Then
			
			ColorNumber = 2;
			
			NewRow 					= FieldsTree.Rows.Add();
			NewRow.FieldPresentation	= FieldsGroup.FieldsGroupName;
			NewRow.FieldsGroupName		= FieldsGroup.FieldsGroupName;
			NewRow.ColorNumber 			= ?(FieldsGroup.GroupRequiredFilling, 1, 0);
			AddFields(NewRow, FieldsGroup, ColorNumber, IsCustomFieldsGroup);
			Continue;
			
		ElsIf FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsMandatoryForFillingGroupName() Then
			
			ColorNumber = 1;
			
		EndIf;
		
		AddFields(FieldsTree, FieldsGroup, ColorNumber);
		
	EndDo;
	
	ValueToFormAttribute(FieldsTree, "ImportFieldsTree");
	
EndProcedure

#EndRegion

#Region FormEvents

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SpreadsheetDocument = Parameters.SpreadsheetDocument;
	FillImportFieldsTree(Parameters.FillingObjectFullName);
	
EndProcedure

#EndRegion

#Region FormAttributesEvents

&AtClient
Procedure ImportFiledsTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	Field = ImportFieldsTree.FindByID(SelectedRow);
	If Not IsBlankString(Field.FieldsGroupName) Then
		
		ShowMessageBox(, NStr("en='Specify the group field...'"));
		Return;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("Presentation", Field.FieldPresentation);
	Result.Insert("Value", 		Field.FieldName);
	
	If FieldAlreadySpecifiedInAnotherColumn(Field) Then
		
		Result.Insert("CancelSelectionInColumn", Field.ColumnNumber);
		
	EndIf;
	
	Close(Result);
	
EndProcedure

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
