import { expect, it } from 'vitest'
import { installRandomUUID } from './random-uuid'

it('provides version 4 UUIDs where the browser hides randomUUID outside secure contexts', () => {
  const insecure = { getRandomValues: globalThis.crypto.getRandomValues.bind(globalThis.crypto) } as unknown as Crypto
  installRandomUUID(insecure)
  const ids = new Set(Array.from({ length: 100 }, () => insecure.randomUUID()))
  expect(ids.size).toBe(100)
  for (const id of ids) expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
})

it('keeps the native implementation when it exists', () => {
  const native = () => '00000000-0000-4000-8000-000000000000' as const
  const secure = { randomUUID: native } as unknown as Crypto
  installRandomUUID(secure)
  expect(secure.randomUUID).toBe(native)
})
