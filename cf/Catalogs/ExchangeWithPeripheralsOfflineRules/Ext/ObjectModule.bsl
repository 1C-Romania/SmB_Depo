#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	NoncheckableAttributeArray = New Array;
	
	If PeripheralsType = Enums.PeripheralTypes.CashRegistersOffline Then
		NoncheckableAttributeArray.Add("WeighingUnits");
	EndIf;
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	AdditionalProperties.Insert(
		"RecordChanges",
		Not IsNew()
		AND (WeightProductPrefix <> Ref.WeightProductPrefix
		   OR WeighingUnits <> Ref.WeighingUnits
		)
	);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If AdditionalProperties.RecordChanges Then
		
		Query = New Query(
		"SELECT
		|	Peripherals.InfobaseNode AS InfobaseNode,
		|	Peripherals.Ref AS Ref
		|FROM
		|	Catalog.Peripherals AS Peripherals
		|WHERE
		|	Peripherals.ExchangeRule = &ExchangeRule
		|	AND Peripherals.InfobaseNode <> VALUE(ExchangePlan.ExchangeWithPeripheralsOffline.EmptyRef)
		|");
		
		Query.SetParameter("ExchangeRule", Ref);
		
		Result = Query.Execute();
		Selection = Result.Select();
		
		While Selection.Next() Do
			ExchangePlans.RecordChanges(Selection.InfobaseNode, Metadata.InformationRegisters.ProductsCodesPeripheralOffline);
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf