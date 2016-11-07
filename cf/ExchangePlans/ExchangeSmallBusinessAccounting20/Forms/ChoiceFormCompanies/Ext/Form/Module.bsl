&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("CompaniesArray") Then
		Return;
	EndIf;
	
	FillCompanies(Parameters.CompaniesArray);
	
EndProcedure

&AtClient
Procedure WriteClose(Command)
	
	CloseParametersForms = New Structure();
	CloseParametersForms.Insert("AddressTableInTemporaryStorage", GenerateTableSelectedValues());
	CloseParametersForms.Insert("TableNameForFill",          "Companies");
	
	NotifyChoice(CloseParametersForms);
	
EndProcedure

&AtClient
Procedure Unmark(Command)
	FillMarks(False);
EndProcedure

&AtClient
Procedure MarkAll(Command)
	FillMarks(True);
EndProcedure

&AtServer
Procedure FillMarks(MarkValue)
	
	TableFillValues = Companies.Unload();
	TableFillValues.FillValues(MarkValue, "Use");
	Companies.Load(TableFillValues);
	
EndProcedure

&AtServer
Procedure FillCompanies(CompaniesArray)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Companies.Ref AS Company,
	|	CASE
	|		WHEN Companies.Ref IN (&PassedValuesArray)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Use
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Companies.DeletionMark = FALSE";
	
	Query.SetParameter("PassedValuesArray", CompaniesArray);
	Companies.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Function GenerateTableSelectedValues()

	TableSelectedValues = Companies.Unload(New Structure("Use", True), "Company");
	Return PutToTempStorage(TableSelectedValues, UUID);

EndFunction






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
