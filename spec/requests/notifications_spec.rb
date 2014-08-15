require 'spec_helper'

describe "Notifications" do
	it "rejects malformed notifications" do

		# Send malformed notification callback 
		callback_body = "THIS IS OBVIOUSLY NOT VALID JSON"
		post bitpay_notification_path, callback_body

		# Expect malformed response code
		expect(response).to have_http_status(:unprocessable_entity)
	end

	it "Handles 'paid' notification" do

		order = create(:processing_payment_with_confirming_order).order
		payment = order.payments.first

		# Validate Starting State
		expect(order.state).to eq("confirm")
		expect(payment.state).to eq("processing")

		# Send 'paid' notification callback 
		callback_body = get_fixture("valid_paid_callback.json")
		invoice = get_fixture("valid_paid_invoice.json")

		stub_request(:get, "https://bitpay.com/api/invoice/123BitPayInvoiceID").
         to_return(:status => 200, :body => invoice.to_json)
		
		post bitpay_notification_path, callback_body

        expect(WebMock).to have_requested(:get, "https://bitpay.com/api/invoice/123BitPayInvoiceID")		

		expect(order.reload.state).to eq("complete")
		expect(payment.reload.state).to eq("pending") 

	end

	it "Handles 'confirmed' notification" do

		order = create(:pending_payment_with_complete_order).order
		payment = order.payments.first

		# Validate Starting State
		expect(order.state).to eq("complete")
		expect(payment.state).to eq("pending")

		# Send 'paid' notification callback 
		callback_body = get_fixture("valid_confirmed_callback.json")
		invoice = get_fixture("valid_confirmed_invoice.json")

		stub_request(:get, "https://bitpay.com/api/invoice/123BitPayInvoiceID").
         to_return(:status => 200, :body => invoice.to_json)
		
		post bitpay_notification_path, callback_body
        expect(WebMock).to have_requested(:get, "https://bitpay.com/api/invoice/123BitPayInvoiceID")		

		expect(order.reload.state).to eq("complete")
		expect(payment.reload.state).to eq("completed") 
	end

	it "Handles Overpayment" do
		# Should behave identically to exact payment
		# Could enhance by adding flag/notification for merchant

		payment = create(:processing_payment_with_confirming_order)
		order = payment.order

		# Validate Starting State
		expect(order.state).to eq("confirm")
		expect(order.payments.first.state).to eq("processing")

		# Send 'paid' notification callback 
		callback_body = get_fixture("valid_overpaid_callback.json")
		invoice = get_fixture("valid_overpaid_invoice.json")

		stub_request(:get, "https://bitpay.com/api/invoice/123BitPayInvoiceID").
         to_return(:status => 200, :body => invoice.to_json)
		
		post bitpay_notification_path, callback_body
        expect(WebMock).to have_requested(:get, "https://bitpay.com/api/invoice/123BitPayInvoiceID")		

		expect(order.reload.state).to eq("complete")
		expect(payment.reload.state).to eq("pending") 
	end

	it "Handles Expired Invoices that are later accepted" do
		# An underpaid invoice will not send notifications - however it might be marked expired/paidPartial if the merchant refreshes status
		# In coordination with BitPay support, a merchant can have the invoice marked paid, and it should move from expired to paid properly

		payment = create(:invalid_payment_with_confirming_order)
		order = payment.order

		# Validate Starting State
		expect(order.state).to eq("confirm")
		expect(order.payments.first.state).to eq("invalid")

		invoice = get_fixture("valid_confirmed_invoice.json")

		stub_request(:get, "https://bitpay.com/api/invoice/123BitPayInvoiceID").
         to_return(:status => 200, :body => invoice.to_json)

		# Call the "refresh" method
		get bitpay_refresh_path, payment: payment.id        
        expect(WebMock).to have_requested(:get, "https://bitpay.com/api/invoice/123BitPayInvoiceID")		

		expect(order.reload.state).to eq("complete")
		expect(payment.reload.state).to eq("completed") 
	end

	it "Handles 'invalid' notification"
	it "Handles non-existent orders"
	it "Handles non-existent payments"
	it "Handles false 'paid' notifications"
	it "Handles false 'confirmed' notifications"
	it "Handles 'paid' notifications for Payments in 'invalid' state"
end
