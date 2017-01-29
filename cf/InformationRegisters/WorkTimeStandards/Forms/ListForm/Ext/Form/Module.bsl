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
			Title = NStr("en='Time norms are stored only for the work';ru='Нормы времени хранятся только для работ'");

			Items.List.ReadOnly = True;
			
		ElsIf ProductsAndServices.FixedCost Then
			
			AutoTitle = False;
			Title = NStr("en='""Cost calculation method"" should be ""Time""';ru='""Способ расчета стоимости работ"" должен быть ""Норма времени""'");

			Items.List.ReadOnly = True;
			
		EndIf;

	EndIf;
		
EndProcedure // OnCreateAtServer()
