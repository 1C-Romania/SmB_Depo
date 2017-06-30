Function SetControlMarkIncomplete(Control,Val Value) Export
	
	Control.AutoMarkIncomplete = Control.Enabled;
	Control.MarkIncomplete = Control.AutoMarkIncomplete AND ValueIsNotFilled(Value);

EndFunction

Procedure SetVATNumberMask(Val LocationType, VATNumber, ControlVATNumber) Export
	
	// to do
	// Jack 29.06.2017
	//If LocationType = PredefinedValue("Enum.BusinessPartnersLocationTypes.Domestic") Then
	//	ControlVATNumber.Mask = "999-999-99-99";
	//ElsIf LocationType = PredefinedValue("Enum.BusinessPartnersLocationTypes.EuropeanUnion") Then
	//	ControlVATNumber.Mask = "UUUX99999UUU99";
	//ElsIf LocationType = PredefinedValue("Enum.BusinessPartnersLocationTypes.Foreign") Then
	//	ControlVATNumber.Mask = "";
	//Else
		ControlVATNumber.Mask = "";
	// EndIf;
		
EndProcedure

Function ApplyVATNumberMaskToDomesticVATNumber(Val VATNumber) Export
	
	// mask is 999-999-99-99
	// Jack 29.06.2017
	// to do
	//VATNumber = StringFunctionsClientServer.LeaveOnlyDigitsInString(VATNumber);
	VATNumber = Left(VATNumber,3)+"-"+Mid(VATNumber,4);
	VATNumber = Left(VATNumber,7)+"-"+Mid(VATNumber,8);
	VATNumber = Left(VATNumber,10)+"-"+Mid(VATNumber,11);
	
	Return VATNumber;
	
EndFunction	

Function SetUnsetMarkIncomplete(Control,AutoMarkIncomplete,Value) Export
	
	Control.AutoMarkIncomplete = AutoMarkIncomplete;
	Control.MarkIncomplete = Control.AutoMarkIncomplete AND ValueIsNotFilled(Value);

EndFunction

Function SetControlMarkIncompleteAndEnable(Control, Value, Enabled) Export
	
	Control.Enabled = Enabled;
	Control.AutoMarkIncomplete = Control.Enabled;
	Control.MarkIncomplete = Control.AutoMarkIncomplete AND ValueIsNotFilled(Value);

EndFunction

Function FillDeliveryTimeList(DeliveryTimeList) Export
	
	InitialTime = '000101010600';
	FinishTime  = '000101012000';
	
	While InitialTime <= FinishTime Do
		DeliveryTimeList.Add(InitialTime, Format(InitialTime, "DF=HH:mm"));
		InitialTime = InitialTime + 30*60;
	EndDo;
	
	Return DeliveryTimeList;
	
EndFunction // FillDeliveryTimeList()

Procedure ShowHideManagedColumns(Visibility, Items, ControlName, ColumnsStructure) Export 
	
	For Each KeyAndValue In ColumnsStructure Do
		
		Items[ControlName+KeyAndValue.Key].Visible = Visibility;
		
	EndDo;	
	
EndProcedure

// Fill item's (control) choice list based on given value list
Procedure FillItemsChoiceListByValueList(Item, Val ValueList) Export
	
	Item.ChoiceList.Clear();
	For Each ValueListItem In ValueList Do
		Item.ChoiceList.Add(ValueListItem.Value, ValueListItem.Presentation);
	EndDo;	
	
EndProcedure	