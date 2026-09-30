import { ChatGateway } from './chat.gateway';

/**
 * „scrie..." trimis de un socket care nu face parte din conversație: până
 * acum ajungea la participanți doar pe baza id-ului conversației.
 */
describe('ChatGateway - typing', () => {
  const makeClient = (rooms: string[] = []) => {
    const emit = jest.fn();
    return {
      data: { userId: 'user-a' },
      rooms: new Set(rooms),
      join: jest.fn().mockResolvedValue(undefined),
      to: jest.fn().mockReturnValue({ emit }),
      emit,
    };
  };

  const makeGateway = (participants: string[] | Error) => {
    const conversations = {
      getParticipants: jest.fn(() =>
        participants instanceof Error
          ? Promise.reject(participants)
          : Promise.resolve(participants),
      ),
    };
    const gateway = new ChatGateway(
      {} as never,
      {} as never,
      conversations as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );
    return { gateway, conversations };
  };

  it('trimite din camera deja verificata fara drum la baza', async () => {
    const { gateway, conversations } = makeGateway(['user-a', 'user-b']);
    const client = makeClient(['conversation:c1']);

    await gateway.handleTyping(client as never, 'c1');

    expect(conversations.getParticipants).not.toHaveBeenCalled();
    expect(client.to).toHaveBeenCalledWith('conversation:c1');
    expect(client.emit).toHaveBeenCalledWith('user_typing', {
      userId: 'user-a',
      conversationId: 'c1',
    });
  });

  it('ignora un socket care nu e participant', async () => {
    const { gateway } = makeGateway(['user-b', 'user-c']);
    const client = makeClient();

    await gateway.handleTyping(client as never, 'c1');

    expect(client.join).not.toHaveBeenCalled();
    expect(client.to).not.toHaveBeenCalled();
  });

  it('ignora o conversatie inexistenta', async () => {
    const { gateway } = makeGateway(new Error('not found'));
    const client = makeClient();

    await gateway.handleTyping(client as never, 'nope');

    expect(client.to).not.toHaveBeenCalled();
  });

  it('dupa o reconectare readauga participantul in camera', async () => {
    const { gateway } = makeGateway(['user-a', 'user-b']);
    const client = makeClient();

    await gateway.handleTyping(client as never, 'c1');

    expect(client.join).toHaveBeenCalledWith('conversation:c1');
    expect(client.to).toHaveBeenCalledWith('conversation:c1');
  });
});
