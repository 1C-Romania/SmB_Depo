
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	StructuralUnits.Ref
	|FROM
	|	Catalog.StructuralUnits AS StructuralUnits
	|WHERE
	|	(StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|			OR StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting))";
	
	If Query.Execute().IsEmpty() Then
		Items.List.ReadOnly = True;
		AutoTitle = False;
		Title = NStr("en='UTII application is provided if the retail warehouses are entered';ru='Применение ЕНВД предусмотрено, если заведены розничные склады'");
	EndIf;
	
EndProcedure



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
