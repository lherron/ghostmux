import Foundation
import GhosttyLib

func executeInputPlan(
  _ operations: [InputPlanOperation],
  to terminalId: String,
  client: GhosttyClient,
  policy: InputPlanPolicy
) throws {
  for (index, operation) in operations.enumerated() {
    if index == operations.count - 1, policy.appendEnter,
      let delayMicros = policy.appendEnterDelayMicros
    {
      usleep(useconds_t(delayMicros))
    }

    switch operation {
    case .text(let text):
      try client.sendText(terminalId: terminalId, text: text)
    case .key(let stroke):
      try client.sendKey(terminalId: terminalId, stroke: stroke)
    }
  }
}
