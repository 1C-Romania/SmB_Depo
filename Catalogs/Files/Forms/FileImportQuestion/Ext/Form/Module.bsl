
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	BigFiles = Parameters.BigFiles;
	
	MaximumFileSize = Int(FileFunctions.MaximumFileSize() / (1024 * 1024));
	
	Message =
	StringFunctionsClientServer.PlaceParametersIntoString(
	    NStr("en='Some of the files exceed the size limit (%1 Mb) and will not be added to storage.
		|Continue import?';ru='Некоторые файлы превышают предельный размер (%1 Мб) и не будут добавлены в хранилище.
		|Продолжить импорт?'"),
	    String(MaximumFileSize) );
		
	If Parameters.Property("Title") Then
		Title = Parameters.Title;
	EndIf;
	
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
