// Parameters are awaited:
//
//     IdentifierBasicForm      - UUID - Form identifier through
//                                                                 a storage of which exchange is executed.
//     SchemaURLComposition            - String - Address of a temporary storage of
//                                                layout schema for which the settings are edited.
//     SelectionLinkerSettingsAddress - String - Address of a temporary storage of the edited settings.
//     SelectionAreaPresentation      - String - Presentation for title forming.
//
// Returned as a selection result:
//
//     Undefined - Reject editing.
//     String       - Address of a temporary storage of new linker settings.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	IdentifierBasicForm = Parameters.IdentifierBasicForm;
	
	ComposerPreFilter = New DataCompositionSettingsComposer;
	ComposerPreFilter.Initialize( 
		New DataCompositionAvailableSettingsSource(Parameters.SchemaURLComposition) );
		
	SelectionLinkerSettingsAddress = Parameters.SelectionLinkerSettingsAddress;
	ComposerPreFilter.LoadSettings(GetFromTempStorage(SelectionLinkerSettingsAddress));
	DeleteFromTempStorage(SelectionLinkerSettingsAddress);
	
	Title = StrReplace( NStr("en='Filter rules ""%1""';ru='Правила отбора ""%1""'"), "%1", Parameters.SelectionAreaPresentation) 
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	
	If Modified Then
		ChoiceValue = SelectionLinkerSettingsAddress();
		NotifyChoice(ChoiceValue);
	Else
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function SelectionLinkerSettingsAddress()
	
	Return PutToTempStorage(ComposerPreFilter.Settings, IdentifierBasicForm)
	
EndFunction

#EndRegion
 

