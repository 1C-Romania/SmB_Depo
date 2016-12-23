
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














