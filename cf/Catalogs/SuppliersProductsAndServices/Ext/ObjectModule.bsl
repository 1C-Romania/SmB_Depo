#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure BeforeWrite(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	SuppliersProductsAndServices.Ref
	|FROM
	|	Catalog.SuppliersProductsAndServices AS SuppliersProductsAndServices
	|WHERE
	|	SuppliersProductsAndServices.Owner = &Owner
	|	AND SuppliersProductsAndServices.SKU = &SKU
	|	AND SuppliersProductsAndServices.ID = &ID
	|	AND SuppliersProductsAndServices.ProductsAndServices = &ProductsAndServices
	|	AND SuppliersProductsAndServices.Characteristic = &Characteristic
	|	AND SuppliersProductsAndServices.Ref <> &CurrentRef";
	
	Query.SetParameter("Owner", Owner);
	Query.SetParameter("SKU", SKU);
	Query.SetParameter("ID", ID);
	Query.SetParameter("ProductsAndServices", ProductsAndServices);
	Query.SetParameter("Characteristic", Characteristic);
	Query.SetParameter("CurrentRef", Ref);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Mapping ""%1,%2,%3 - %4,%5"" is already in the catalog. Writing is cancelled.';ru='Соответствие ""%1,%2,%3 - %4,%5"" уже присутствует в справочнике. Запись отменена.'"),
			Owner, SKU, ID, ProductsAndServices, Characteristic
		);
		
		Message = New UserMessage();
		Message.Text = MessageText;
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndIf