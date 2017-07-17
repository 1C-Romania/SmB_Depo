////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("ProductsAndServices") Then

		ProductsAndServices = Parameters.Filter.ProductsAndServices;

		If ProductsAndServices.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.Work Then
			
			AutoTitle = False;
			Title = NStr("en='Standard hours are stored only for works';ru='Нормы времени хранятся только для работ'");

			Items.List.ReadOnly = True;
			
		ElsIf ProductsAndServices.FixedCost Then
			
			AutoTitle = False;
			Title = NStr("en='""Work cost calculation method"" should be ""Standard time""';ru='""Способ расчета стоимости работ"" должен быть ""Норма времени""'");

			Items.List.ReadOnly = True;
			
		EndIf;

	EndIf;
		
EndProcedure // OnCreateAtServer()
